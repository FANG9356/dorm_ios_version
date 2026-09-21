import SwiftUI
import SwiftData

struct BillsTabView: View {
    @Binding var showingEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var allPayments: [Payment]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var editingPayment: Payment?
    @State private var deletingPayment: Payment?
    @State private var ledgerErrorMessage: String?
    @State private var searchText = ""

    private var payments: [Payment] { allPayments.filter { !$0.isDeletedLocally } }
    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }
    private var visiblePayments: [Payment] { payments.filter(matchesSearch) }
    private var billSections: [(title: String, subtitle: String, icon: String, payments: [Payment])] {
        [
            (
                "รอรับชำระ",
                "รายการที่ยังต้องติดตาม",
                "clock.fill",
                visiblePayments.filter { $0.paymentStatus == "pending" }
            ),
            (
                "ผ่อนชำระ",
                "รายการที่รับบางส่วนหรืออยู่ในแผนผ่อน",
                "circle.lefthalf.filled",
                visiblePayments.filter { $0.paymentStatus == "partial" || $0.paymentPlan == "installment" }
            ),
            (
                "ชำระแล้ว",
                "ประวัติรับเงินที่ปิดรายการแล้ว",
                "checkmark.circle.fill",
                visiblePayments.filter { $0.paymentStatus == "paid" && $0.paymentPlan != "installment" }
            )
        ].map { section in
            (section.0, section.1, section.2, section.3.sorted { $0.lastUpdated > $1.lastUpdated })
        }.filter { !$0.payments.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ประวัติบิลและธุรกรรม")
                        .font(.custom("SukhumvitSet-Bold", size: 30))
                    Text("รายการนี้สร้างจากลูกบ้าน รอบบิล และการรับชำระของระบบ")
                        .font(.custom("SukhumvitSet-Text", size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ManagementSearchField(
                text: $searchText,
                placeholder: "ค้นหาห้อง, ชื่อลูกบ้าน, รอบบิล..."
            )

            if payments.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", title: "ยังไม่มีข้อมูลบิล")
            } else if visiblePayments.isEmpty {
                emptyState(icon: "magnifyingglass", title: "ไม่พบบิลที่ค้นหา")
            } else {
                ForEach(billSections, id: \.title) { section in
                    BillSectionView(
                        title: section.title,
                        subtitle: section.subtitle,
                        icon: section.icon,
                        payments: section.payments,
                        users: users,
                        onEdit: { editingPayment = $0 },
                        onDelete: { deletingPayment = $0 }
                    )
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(item: $editingPayment) { payment in
            PaymentEditor(payment: payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: payment.month) { draft in
                do {
                    apply(draft, to: payment)
                    _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: modelContext, source: "bill-editor")
                    modelContext.insert(LocalSystemLog(action: "แก้ไขบิล", details: "แก้ไขบิลห้อง \(payment.roomNumber) รอบ \(payment.month)"))
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw error
                }
                Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบบิลนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบบิลห้อง \(deletingPayment?.roomNumber ?? "")", role: .destructive) {
                guard let payment = deletingPayment else { return }
                delete(payment)
                deletingPayment = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
        .onChange(of: showingEditor) { _, isShowing in
            if isShowing {
                showingEditor = false
            }
        }
        .alert("ดำเนินการกับบิลไม่ได้", isPresented: Binding(
            get: { ledgerErrorMessage != nil },
            set: { if !$0 { ledgerErrorMessage = nil } }
        )) {
            Button("ตกลง", role: .cancel) { ledgerErrorMessage = nil }
        } message: {
            Text(ledgerErrorMessage ?? "")
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { deletingPayment != nil },
            set: { if !$0 { deletingPayment = nil } }
        )
    }

    private func emptyState(icon: String, title: String) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.custom("SukhumvitSet-Medium", size: 38))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private func matchesSearch(_ payment: Payment) -> Bool {
        let query = normalizedSearchText
        guard !query.isEmpty else { return true }
        let user = users.first { stableLocalUserID(for: $0) == payment.userId && payment.userId > 0 }
            ?? users.first { $0.roomNumber == payment.roomNumber }
        let status: String
        switch payment.paymentStatus {
        case "paid": status = "ชำระแล้ว"
        case "partial": status = "ชำระบางส่วน ผ่อนชำระ"
        default: status = "รอชำระ"
        }
        let searchable = [
            payment.roomNumber,
            user.map { "\($0.prefix)\($0.firstName) \($0.lastName)" } ?? "",
            payment.month,
            AppDate.thaiMonth(payment.month),
            payment.method,
            payment.paymentPlan,
            status,
            payment.amount.formatted(.number.precision(.fractionLength(0...2)))
        ].joined(separator: " ").lowercased()
        return searchable.contains(query)
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func apply(_ draft: Payment, to payment: Payment) {
        payment.userId = draft.userId
        payment.roomNumber = draft.roomNumber
        payment.rentFee = draft.rentFee
        payment.depositFee = draft.depositFee
        payment.waterFee = draft.waterFee
        payment.electricFee = draft.electricFee
        payment.commonFee = draft.commonFee
        payment.lateFee = draft.lateFee
        payment.applianceFee = draft.applianceFee
        payment.amount = draft.amount
        payment.month = draft.month
        payment.paymentDate = draft.paymentDate
        payment.method = draft.method
        payment.slipPath = draft.slipPath
        payment.slipPathArray = draft.slipPathArray
        payment.dueDate = draft.dueDate
        payment.paymentStatus = draft.paymentStatus
        payment.paidAmount = draft.paidAmount
        payment.paymentPlan = draft.paymentPlan
        payment.installmentPhase = draft.installmentPhase
        payment.lastUpdated = Date()
        payment.isDirty = true
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Bill save error: \(error)")
        }
    }

    private func delete(_ payment: Payment) {
        do {
            try PaymentLedger.ensureInvoiceCanBeDeleted(payment, in: modelContext)
            payment.isDeletedLocally = true
            payment.isDirty = true
            payment.lastUpdated = Date()
            modelContext.insert(LocalSystemLog(action: "ลบบิล", details: "ลบบิลห้อง \(payment.roomNumber) รอบ \(payment.month)"))
            try modelContext.save()
            Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
        } catch {
            modelContext.rollback()
            ledgerErrorMessage = error.localizedDescription
        }
    }

}

private struct BillSectionView: View {
    let title: String
    let subtitle: String
    let icon: String
    let payments: [Payment]
    let users: [DormUser]
    let onEdit: (Payment) -> Void
    let onDelete: (Payment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.custom("SukhumvitSet-Bold", size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(payments.count)")
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, minHeight: 28)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.top, 4)

            ForEach(payments) { payment in
                BillRow(
                    payment: payment,
                    user: userFor(payment),
                    onEdit: { onEdit(payment) },
                    onDelete: { onDelete(payment) }
                )
            }
        }
    }

    private func userFor(_ payment: Payment) -> DormUser? {
        users.first { stableLocalUserID(for: $0) == payment.userId && payment.userId > 0 }
            ?? users.first { $0.roomNumber == payment.roomNumber }
    }
}

private struct BillRow: View {
    let payment: Payment
    let user: DormUser?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 2) {
                        Text(payment.roomNumber)
                            .font(.custom("SukhumvitSet-Bold", size: 22))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text("ห้อง")
                            .font(.custom("SukhumvitSet-Text", size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 64, height: 58)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(tenantName)
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(detailText)
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !dateText.isEmpty {
                            Label(dateText, systemImage: "calendar")
                                .font(.custom("SukhumvitSet-Text", size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                            .foregroundStyle(.primary)
                        Text(statusText)
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(statusColor.opacity(0.12), in: Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Label("แก้ไข", systemImage: "pencil")
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive, action: onDelete) {
                        Label("ลบ", systemImage: "trash")
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(Color.red.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusText: String {
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "บางส่วน"
        default: return "รอชำระ"
        }
    }

    private var statusColor: Color {
        switch payment.paymentStatus {
        case "paid": return .green
        case "partial": return .blue
        default: return .orange
        }
    }

    private var detailText: String {
        var parts = ["รอบบิล \(AppDate.thaiMonth(payment.month))"]
        if payment.paymentPlan == "installment" {
            let phase = payment.installmentPhase > 0 ? "งวด \(payment.installmentPhase)" : "ผ่อนชำระ"
            parts.append(phase)
        } else if !payment.paymentPlan.isEmpty {
            parts.append(payment.paymentPlan)
        }
        if !payment.method.isEmpty {
            parts.append(payment.method)
        }
        return parts.joined(separator: " • ")
    }

    private var tenantName: String {
        guard let user else { return "ไม่พบชื่อลูกบ้าน" }
        let fullName = "\(user.prefix)\(user.firstName) \(user.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "ลูกบ้าน" : fullName
    }

    private var dateText: String {
        if !payment.paymentDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "ชำระวันที่ \(AppDate.thaiDate(payment.paymentDate))"
        }
        if !payment.dueDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "ครบกำหนด \(AppDate.thaiDate(payment.dueDate))"
        }
        return ""
    }
}
