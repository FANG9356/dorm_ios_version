import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct FinanceTabView: View {
    @Binding var showingPaymentEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var allPayments: [Payment]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var selectedMonth = Date()
    @State private var selectedStatus = "ทั้งหมด"
    @State private var searchText = ""
    @State private var selectedBillingUser: DormUser?
    @State private var paymentEditTarget: PaymentEditTarget?
    @State private var deletingPayment: Payment?

    private let statuses = ["ทั้งหมด", "ชำระแล้ว", "รอชำระ", "ชำระบางส่วน"]
    private var payments: [Payment] { allPayments.filter { !$0.isDeletedLocally } }
    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }

    var body: some View {
        VStack(spacing: 16) {
            header
            summaryGrid
            filters
            billingUserList
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .sheet(item: $selectedBillingUser) { user in
            BillingHistorySheet(
                user: user,
                payments: paymentsFor(user),
                onIssueBill: { month in
                    selectedBillingUser = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        paymentEditTarget = .draft(generatedPayment(for: user, month: month))
                    }
                },
                onEdit: { payment in
                    selectedBillingUser = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        paymentEditTarget = .existing(payment)
                    }
                },
                onDelete: { payment in
                    selectedBillingUser = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        deletingPayment = payment
                    }
                },
                onMarkPaid: { payment in
                    markPaid(payment)
                },
                onSendLine: { payment in
                    modelContext.insert(LocalSystemLog(action: "รอเชื่อมต่อ LINE", details: "เตรียมส่งแจ้งเตือนบิลห้อง \(payment.roomNumber) รอบ \(payment.month)"))
                    saveAndPush()
                }
            )
            .iphoneSheetStyle()
        }
        .sheet(item: $paymentEditTarget) { target in
            PaymentEditor(payment: target.payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: target.payment.month.isEmpty ? monthKey : target.payment.month) { draft in
                switch target {
                case .existing(let payment):
                    apply(draft, to: payment)
                    modelContext.insert(LocalSystemLog(action: "แก้ไขรายการชำระเงิน", details: "แก้ไขรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
                case .draft:
                    draft.lastUpdated = Date()
                    draft.isDirty = true
                    modelContext.insert(draft)
                    modelContext.insert(LocalSystemLog(action: "ออกบิล", details: "ออกบิลห้อง \(draft.roomNumber) รอบ \(draft.month)"))
                }
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบรายการชำระเงินนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบรายการห้อง \(deletingPayment?.roomNumber ?? "")", role: .destructive) {
                guard let payment = deletingPayment else { return }
                payment.isDeletedLocally = true
                payment.isDirty = true
                payment.lastUpdated = Date()
                modelContext.insert(LocalSystemLog(action: "ลบรายการชำระเงิน", details: "ลบรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
                saveAndPush()
                deletingPayment = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
        .onAppear {
            ensurePaymentsForSelectedMonth()
        }
        .onChange(of: selectedMonth) { _, _ in
            ensurePaymentsForSelectedMonth()
        }
        .onChange(of: showingPaymentEditor) { _, isShowing in
            if isShowing {
                showingPaymentEditor = false
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { deletingPayment != nil },
            set: { if !$0 { deletingPayment = nil } }
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("สรุปยอดเดือนนี้")
                    .font(.custom("SukhumvitSet-Bold", size: 28))
                    .foregroundStyle(.primary)
                Text("ติดตามยอดรับแล้ว ค้างชำระ และรายการที่ต้องดูแล")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var summaryGrid: some View {
        let monthPayments = payments.filter { $0.month == monthKey }
        let received = monthPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + $1.paidAmount }
        let pending = monthPayments.filter { $0.paymentStatus == "pending" }.reduce(0) { $0 + $1.amount }
        let partial = monthPayments.filter { $0.paymentStatus == "partial" }.reduce(0) { $0 + $1.paidAmount }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            FinanceSummaryCard(title: "รับแล้ว", amount: received, color: .green, icon: "checkmark.circle.fill")
            FinanceSummaryCard(title: "ค้างชำระ", amount: pending, color: .orange, icon: "clock.fill")
            FinanceSummaryCard(title: "ชำระบางส่วน", amount: partial, color: .blue, icon: "circle.lefthalf.filled")
            FinanceSummaryCard(title: "รายการทั้งหมด", amount: Double(monthPayments.count), color: .indigo, icon: "list.bullet.rectangle.fill", isCount: true)
        }
    }

    private var filters: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("ค้นหาห้องหรือชื่อลูกบ้าน", text: $searchText)
                        .font(.custom("SukhumvitSet-Text", size: 13))

                    DatePicker("", selection: $selectedMonth, displayedComponents: [.date])
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "th_TH"))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(statuses, id: \.self) { status in
                            Button(status) {
                                selectedStatus = status
                            }
                            .font(.custom("SukhumvitSet-Medium", size: 11))
                            .foregroundStyle(selectedStatus == status ? .white : .secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(selectedStatus == status ? Color.indigo : Color.primary.opacity(0.07), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var paymentList: some View {
        let visiblePayments = payments.filter { payment in
            let matchesMonth = payment.month == monthKey
            let matchesStatus = selectedStatus == "ทั้งหมด" || statusLabel(for: payment) == selectedStatus
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let user = userFor(payment)
            let name = "\(user?.firstName ?? "") \(user?.lastName ?? "")".lowercased()
            let matchesSearch = query.isEmpty || payment.roomNumber.lowercased().contains(query) || name.contains(query)
            return matchesMonth && matchesStatus && matchesSearch
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("รายการประจำเดือน")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                Spacer()
                Text("\(visiblePayments.count) รายการ")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if visiblePayments.isEmpty {
                GlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีรายการตามตัวกรอง")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
            } else {
                ForEach(visiblePayments) { payment in
                    PaymentRow(
                        payment: payment,
                        user: userFor(payment),
                        status: statusLabel(for: payment),
                        onMarkPaid: { markPaid(payment) },
                        onEdit: { paymentEditTarget = .existing(payment) },
                        onDelete: { deletingPayment = payment }
                    )
                }
            }
        }
    }

    private var billingUserList: some View {
        let visibleUsers = usersForBilling.filter { user in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }
            let name = "\(user.prefix)\(user.firstName) \(user.lastName)".lowercased()
            return user.roomNumber.lowercased().contains(query) || name.contains(query)
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ห้องที่ต้องติดตาม")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                Spacer()
                Text("\(visibleUsers.count) ห้อง")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if visibleUsers.isEmpty {
                GlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีลูกบ้านที่ต้องออกบิล")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(visibleUsers) { user in
                        BillingUserCard(
                            user: user,
                            currentPayment: paymentFor(user, month: monthKey),
                            dueDay: dueDayText(for: user)
                        ) {
                            selectedBillingUser = user
                        }
                    }
                }
            }
        }
    }

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: selectedMonth)
    }

    private func userFor(_ payment: Payment) -> DormUser? {
        users.first { $0.serverId == payment.userId && payment.userId > 0 } ?? users.first { $0.roomNumber == payment.roomNumber }
    }

    private var usersForBilling: [DormUser] {
        users
            .filter {
                !$0.isDeletedLocally &&
                $0.status != "ย้ายออกแล้ว" &&
                !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { clean($0.roomNumber).localizedStandardCompare(clean($1.roomNumber)) == .orderedAscending }
    }

    private func paymentsFor(_ user: DormUser) -> [Payment] {
        payments.filter { isPayment($0, for: user) }
    }

    private func paymentFor(_ user: DormUser, month: String) -> Payment? {
        payments.first { isPayment($0, for: user) && $0.month == month && $0.paymentPlan != "installment" }
    }

    private func isPayment(_ payment: Payment, for user: DormUser) -> Bool {
        clean(payment.roomNumber) == clean(user.roomNumber) ||
        (payment.userId > 0 && (user.serverId == payment.userId || Int(truncatingIfNeeded: user.id.hashValue) == payment.userId))
    }

    private func dueDayText(for user: DormUser) -> String {
        let day = Int(String(user.moveInDate.suffix(2))) ?? 1
        return "ครบกำหนดวันที่ \(max(1, min(day, 31)))"
    }

    private func statusLabel(for payment: Payment) -> String {
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "ชำระบางส่วน"
        default: return "รอชำระ"
        }
    }

    private func markPaid(_ payment: Payment) {
        payment.paymentStatus = "paid"
        payment.paidAmount = payment.amount
        payment.paymentDate = currentDateString()
        payment.lastUpdated = Date()
        payment.isDirty = true
        modelContext.insert(LocalSystemLog(action: "รับชำระเงิน", details: "รับชำระเต็มจำนวน ห้อง \(payment.roomNumber) รอบ \(payment.month)"))
        saveAndPush()
    }

    private func apply(_ draft: Payment, to payment: Payment) {
        payment.userId = draft.userId
        payment.roomNumber = draft.roomNumber
        payment.rentFee = draft.rentFee
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
        payment.waterMeterPrev = draft.waterMeterPrev
        payment.waterMeterCurr = draft.waterMeterCurr
        payment.electricMeterPrev = draft.electricMeterPrev
        payment.electricMeterCurr = draft.electricMeterCurr
        payment.paymentPlan = draft.paymentPlan
        payment.installmentPhase = draft.installmentPhase
        payment.dueDate = draft.dueDate
        payment.paymentStatus = draft.paymentStatus
        payment.slipPathArray = draft.slipPathArray
        payment.paidAmount = draft.paidAmount
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
            print("Payment save error: \(error)")
        }
    }

    private func ensurePaymentsForSelectedMonth() {
        let activeUsers = users.filter {
            !$0.isDeletedLocally &&
            !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.status != "ย้ายออกแล้ว"
        }
        guard !activeUsers.isEmpty else { return }

        var didCreate = false
        for user in activeUsers {
            let hasMoveInInstallment = monthKey == moveInMonth(for: user) && payments.contains { payment in
                payment.month == monthKey &&
                payment.paymentPlan == "installment" &&
                clean(payment.roomNumber) == clean(user.roomNumber)
            }
            let hasRegularPayment = payments.contains { payment in
                payment.month == monthKey &&
                payment.paymentPlan != "installment" &&
                clean(payment.roomNumber) == clean(user.roomNumber)
            }

            guard shouldCreatePayment(for: user, month: monthKey),
                  !hasMoveInInstallment,
                  !hasRegularPayment else {
                continue
            }

            let payment = generatedPayment(for: user, month: monthKey)
            modelContext.insert(payment)
            modelContext.insert(LocalSystemLog(action: "สร้างรายการชำระอัตโนมัติ", details: "สร้างรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
            didCreate = true
        }

        guard didCreate else { return }
        saveAndPush()
    }

    private func shouldCreatePayment(for user: DormUser, month: String) -> Bool {
        if user.status == "จอง" {
            return month == moveInMonth(for: user)
        }

        let moveInMonth = moveInMonth(for: user)
        guard !moveInMonth.isEmpty else { return true }
        return month >= moveInMonth
    }

    private func generatedPayment(for user: DormUser, month: String) -> Payment {
        let payment = Payment(month: month)
        let roomType = roomType(for: user)
        let rent = roomType?.price ?? 0
        let isBooking = user.status == "จอง"
        let isMoveInMonth = month == moveInMonth(for: user)
        let amount = isBooking ? user.deposit : rent + (isMoveInMonth ? user.deposit : 0)

        payment.userId = user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue)
        payment.roomNumber = user.roomNumber
        payment.rentFee = isBooking ? user.deposit : rent
        payment.waterFee = 0
        payment.electricFee = 0
        payment.commonFee = 0
        payment.lateFee = 0
        payment.applianceFee = 0
        payment.amount = amount
        payment.method = paymentMethodLabel(for: user)
        payment.slipPath = user.bookingSlips.first ?? ""
        payment.slipPathArray = user.bookingSlips
        payment.paymentPlan = isBooking ? "booking" : "monthly"
        payment.installmentPhase = user.installmentMonths
        payment.dueDate = dueDateKey(for: month)
        payment.paymentStatus = inferredPaymentStatus(for: user, isMoveInMonth: isMoveInMonth)
        payment.paidAmount = payment.paymentStatus == "paid" ? amount : (payment.paymentStatus == "partial" ? user.installmentAmount : 0)
        payment.lastUpdated = Date()
        payment.isDirty = true
        return payment
    }

    private func inferredPaymentStatus(for user: DormUser, isMoveInMonth: Bool) -> String {
        guard isMoveInMonth else { return "pending" }
        if user.paymentMethod == "installment" { return "partial" }
        if user.paymentMethod == "full_payment" { return "paid" }
        return "pending"
    }

    private func paymentMethodLabel(for user: DormUser) -> String {
        let method = user.paymentMethod == "installment" ? "ผ่อนชำระ" : (user.paymentMethod == "full_payment" ? "ชำระเต็มจำนวน" : "รอระบุ")
        let channel = user.paymentChannel == "cash" ? "เงินสด" : (user.paymentChannel == "bank_transfer" ? "โอนผ่านธนาคาร" : "ยังไม่ได้ระบุช่องทาง")
        return "\(method) • \(channel)"
    }

    private func roomType(for user: DormUser) -> RoomType? {
        guard let room = rooms.first(where: { clean($0.roomNumber) == clean(user.roomNumber) }) else { return nil }
        return roomTypes.first { clean($0.name) == clean(room.roomType) }
    }

    private func moveInMonth(for user: DormUser) -> String {
        String(user.moveInDate.prefix(7))
    }

    private func dueDateKey(for month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        guard let date = formatter.date(from: "\(month)-01") else { return "" }

        var components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        components.month = (components.month ?? 1) + 1
        components.day = 0
        let dueDate = Calendar(identifier: .gregorian).date(from: components) ?? date
        return formatter.string(from: dueDate)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private enum PaymentEditTarget: Identifiable {
    case existing(Payment)
    case draft(Payment)

    var id: UUID { payment.id }
    var payment: Payment {
        switch self {
        case .existing(let payment), .draft(let payment):
            return payment
        }
    }
}

private struct BillingUserCard: View {
    let user: DormUser
    let currentPayment: Payment?
    let dueDay: String
    let action: () -> Void

    private var fullName: String {
        "\(user.prefix)\(user.firstName) \(user.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(user.roomNumber)
                            .font(.custom("SukhumvitSet-Bold", size: 24))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer()

                        Text(statusText)
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(statusColor.opacity(0.13), in: Capsule())
                    }

                    Text(fullName.isEmpty ? "ลูกบ้าน" : fullName)
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)

                    Label(dueDay, systemImage: "calendar")
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        guard let currentPayment else { return "รอออกบิล" }
        switch currentPayment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "บางส่วน"
        case "checking": return "รอตรวจ"
        default: return "รอชำระ"
        }
    }

    private var statusColor: Color {
        guard let currentPayment else { return .secondary }
        switch currentPayment.paymentStatus {
        case "paid": return .green
        case "partial": return .blue
        case "checking": return .yellow
        default: return .orange
        }
    }
}

private struct BillingHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let user: DormUser
    let payments: [Payment]
    let onIssueBill: (String) -> Void
    let onEdit: (Payment) -> Void
    let onDelete: (Payment) -> Void
    let onMarkPaid: (Payment) -> Void
    let onSendLine: (Payment) -> Void

    private var cycles: [BillingCycle] {
        BillingCycle.generate(
            moveInDate: user.moveInDate,
            contractEndDate: user.contractEndDate,
            indefiniteContract: user.indefiniteContract == 1
        )
    }

    private var fullName: String {
        "\(user.prefix)\(user.firstName) \(user.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    historyHeader

                    ForEach(Array(cycles.enumerated()), id: \.element.monthId) { index, cycle in
                        BillingCycleRow(
                            number: index + 1,
                            cycle: cycle,
                            payment: payment(for: cycle.monthId),
                            onIssueBill: { onIssueBill(cycle.monthId) },
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onMarkPaid: onMarkPaid,
                            onSendLine: onSendLine
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("ประวัติการชำระเงิน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var historyHeader: some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(user.roomNumber)
                        .font(.custom("SukhumvitSet-Bold", size: 28))
                        .foregroundStyle(.primary)
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78, height: 70)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(fullName.isEmpty ? "ลูกบ้าน" : fullName)
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundStyle(.primary)
                    Text("ระบบคำนวณรอบบิลรายเดือนจากวันเข้าอยู่และสัญญา")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }

    private func payment(for month: String) -> Payment? {
        payments
            .filter { $0.month == month }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .first
    }
}

private struct BillingCycleRow: View {
    let number: Int
    let cycle: BillingCycle
    let payment: Payment?
    let onIssueBill: () -> Void
    let onEdit: (Payment) -> Void
    let onDelete: (Payment) -> Void
    let onMarkPaid: (Payment) -> Void
    let onSendLine: (Payment) -> Void
    @State private var showingSlipPreview = false
    @State private var showingReceipt = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(number)")
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(payment == nil ? Color.secondary : Color.green)
                        .frame(width: 34, height: 34)
                        .background((payment == nil ? Color.primary.opacity(0.06) : Color.green.opacity(0.14)), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(cycle.label)
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                            .foregroundStyle(cycle.isFuture && payment == nil ? .secondary : .primary)
                        Text("กำหนดชำระวันที่ \(cycle.dueDay)")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(statusText)
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .foregroundStyle(statusColor)
                        if let payment {
                            Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                actionContent
            }
            .opacity(cycle.isFuture && payment == nil ? 0.62 : 1)
        }
        .fullScreenCover(isPresented: $showingSlipPreview) {
            if !slipImages.isEmpty {
                SlipPreviewView(images: slipImages)
            }
        }
        .fullScreenCover(isPresented: $showingReceipt) {
            if let payment {
                PaymentReceiptView(payment: payment, cycle: cycle)
            }
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        if let payment {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if payment.paymentStatus != "paid" {
                    compactAction("รับชำระ", icon: "checkmark.circle.fill", color: .green) {
                        onMarkPaid(payment)
                    }
                }
                if !slipImages.isEmpty {
                    compactAction("หลักฐาน", icon: "photo.on.rectangle", color: .primary) {
                        showingSlipPreview = true
                    }
                }
                if payment.paymentStatus == "paid" {
                    compactAction("ใบเสร็จ", icon: "doc.richtext", color: .blue) {
                        showingReceipt = true
                    }
                }
                compactAction("แก้ไข", icon: "pencil", color: .blue) {
                    onEdit(payment)
                }
                compactAction("ลบ", icon: "trash", color: .red) {
                    onDelete(payment)
                }
                compactAction("LINE", icon: "paperplane.fill", color: .green) {
                    onSendLine(payment)
                }
            }
        } else {
            Button(action: onIssueBill) {
                HStack(spacing: 8) {
                    Image(systemName: cycle.isFuture ? "doc.badge.plus" : "doc.text.fill")
                    Text(cycle.isFuture ? "เตรียมบิลล่วงหน้า" : "ออกบิล / รับชำระ")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .foregroundStyle(cycle.isFuture ? Color.secondary : Color.blue)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var slipImages: [UIImage] {
        guard let payment else { return [] }
        var paths = payment.slipPathArray
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }
        return paths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }

    private func compactAction(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.custom("SukhumvitSet-Bold", size: 11))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        guard let payment else {
            return cycle.isFuture ? "ยังไม่ถึงรอบบิล" : "รอออกบิล"
        }
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "ชำระบางส่วน"
        case "checking": return "รอตรวจสอบสลิป"
        default: return "รอชำระเงิน"
        }
    }

    private var statusColor: Color {
        guard let payment else { return cycle.isFuture ? .secondary : .orange }
        switch payment.paymentStatus {
        case "paid": return .green
        case "partial": return .blue
        case "checking": return .yellow
        default: return .orange
        }
    }
}

private struct PaymentReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    let payment: Payment
    let cycle: BillingCycle
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.94)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ReceiptExportCard(payment: payment, cycle: cycle)
                            .padding(.horizontal, 18)
                            .padding(.top, 12)

                        if let saveMessage {
                            Text(saveMessage)
                                .font(.custom("SukhumvitSet-Medium", size: 12))
                                .foregroundStyle(.white.opacity(0.72))
                                .padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("ใบเสร็จ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        shareImage = renderedReceiptImage()
                        showingShareSheet = shareImage != nil
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(.white)

                    Button {
                        saveReceipt()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .foregroundStyle(.white)

                    Button {
                        printReceipt()
                    } label: {
                        Image(systemName: "printer")
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareImage {
                ActivityShareSheet(items: [shareImage])
            }
        }
    }

    private func saveReceipt() {
        guard let image = renderedReceiptImage() else {
            saveMessage = "สร้างรูปใบเสร็จไม่สำเร็จ"
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        saveMessage = "บันทึกใบเสร็จลงรูปภาพแล้ว"
    }

    private func printReceipt() {
        guard let image = renderedReceiptImage() else {
            saveMessage = "สร้างเอกสารสำหรับพิมพ์ไม่สำเร็จ"
            return
        }
        let controller = UIPrintInteractionController.shared
        controller.printInfo = UIPrintInfo(dictionary: nil)
        controller.printInfo?.outputType = .general
        controller.printInfo?.jobName = "DormiNet Receipt \(payment.roomNumber) \(cycle.monthId)"
        controller.printingItem = image
        controller.present(animated: true)
    }

    @MainActor
    private func renderedReceiptImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            ReceiptExportCard(payment: payment, cycle: cycle)
                .frame(width: 820)
                .padding(42)
                .background(Color.white)
        )
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ReceiptExportCard: View {
    let payment: Payment
    let cycle: BillingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DormiNet")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.black)
                    Text("ใบเสร็จรับเงิน")
                        .font(.custom("SukhumvitSet-Bold", size: 28))
                        .foregroundStyle(.black)
                }

                Spacer()

                Text(payment.paymentStatus == "paid" ? "ชำระแล้ว" : "ยังไม่ปิดบิล")
                    .font(.custom("SukhumvitSet-Bold", size: 13))
                    .foregroundStyle(.black.opacity(0.72))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                infoBox("ห้อง", payment.roomNumber)
                infoBox("รอบบิล", cycle.label)
                infoBox("วันที่ชำระ", thaiDate(payment.paymentDate))
            }

            VStack(spacing: 0) {
                receiptLine("ช่องทางชำระเงิน", thaiPaymentMethod)
                divider
                receiptLine("ค่าเช่า", currency(payment.rentFee))
                receiptLine("ค่าน้ำ", currency(payment.waterFee))
                receiptLine("ค่าไฟ", currency(payment.electricFee))
                receiptLine("ค่าส่วนกลาง", currency(payment.commonFee))
                receiptLine("ค่าอุปกรณ์เสริม", currency(payment.applianceFee))
                receiptLine("ค่าปรับล่าช้า", currency(payment.lateFee))
                divider
                receiptLine("ยอดรวม", currency(payment.amount), isTotal: true)
                receiptLine("รับชำระแล้ว", currency(payment.paidAmount), isTotal: true)
                receiptLine("ยอดคงเหลือ", currency(max(payment.amount - payment.paidAmount, 0)), isTotal: true)
            }
            .padding(.vertical, 6)

            HStack {
                Text("เอกสารนี้สร้างจากข้อมูลภายในเครื่องของระบบ DormiNet")
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.gray)
                Spacer()
                Text(generatedDateText)
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.gray)
            }
        }
        .padding(26)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoBox(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("SukhumvitSet-Medium", size: 11))
                .foregroundStyle(.gray)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.09))
            .frame(height: 1)
            .padding(.vertical, 8)
    }

    private func receiptLine(_ title: String, _ value: String, isTotal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.custom(isTotal ? "SukhumvitSet-Bold" : "SukhumvitSet-Text", size: isTotal ? 15 : 13))
                .foregroundStyle(isTotal ? Color.black : Color.gray)
            Spacer(minLength: 18)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: isTotal ? 18 : 14))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 5)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "th_TH")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2

        let amount = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(amount) บาท"
    }

    private var thaiPaymentMethod: String {
        let trimmed = payment.method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }

        return trimmed
            .replacingOccurrences(of: "เงินโอน (Transfer)", with: "โอนผ่านธนาคาร")
            .replacingOccurrences(of: "เงินสด (Cash)", with: "เงินสด")
            .replacingOccurrences(of: "Transfer", with: "โอนผ่านธนาคาร")
            .replacingOccurrences(of: "Cash", with: "เงินสด")
            .replacingOccurrences(of: "Full payment", with: "ชำระเต็มจำนวน")
            .replacingOccurrences(of: "Installment", with: "ผ่อนชำระ")
    }

    private var generatedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        formatter.dateFormat = "d MMMM yyyy เวลา HH:mm น."
        return formatter.string(from: Date())
    }

    private func thaiDate(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }

        let inputFormatter = DateFormatter()
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        inputFormatter.calendar = Calendar(identifier: .gregorian)

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "th_TH")
        outputFormatter.calendar = Calendar(identifier: .buddhist)
        outputFormatter.dateFormat = "d MMMM yyyy"

        for format in ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ"] {
            inputFormatter.dateFormat = format
            if let date = inputFormatter.date(from: trimmed) {
                return outputFormatter.string(from: date)
            }
        }

        return trimmed
    }
}

private struct BillingCycle {
    let monthId: String
    let label: String
    let dueDay: Int
    let isFuture: Bool

    static func generate(moveInDate: String, contractEndDate: String, indefiniteContract: Bool) -> [BillingCycle] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)

        let moveIn = formatter.date(from: String(moveInDate.prefix(10))) ?? Date()
        let end = indefiniteContract ? Calendar(identifier: .gregorian).date(byAdding: .month, value: 12, to: moveIn) ?? moveIn : (formatter.date(from: String(contractEndDate.prefix(10))) ?? Calendar(identifier: .gregorian).date(byAdding: .month, value: 12, to: moveIn) ?? moveIn)
        let dueDay = Calendar(identifier: .gregorian).component(.day, from: moveIn)
        let todayMonth = monthKey(for: Date())

        var result: [BillingCycle] = []
        var cursor = Calendar(identifier: .gregorian).date(from: Calendar(identifier: .gregorian).dateComponents([.year, .month], from: moveIn)) ?? moveIn
        let endMonth = Calendar(identifier: .gregorian).date(from: Calendar(identifier: .gregorian).dateComponents([.year, .month], from: end)) ?? end

        while cursor <= endMonth && result.count < 60 {
            let monthId = monthKey(for: cursor)
            result.append(BillingCycle(
                monthId: monthId,
                label: monthLabel(for: cursor),
                dueDay: dueDay,
                isFuture: monthId > todayMonth
            ))
            cursor = Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: cursor) ?? cursor
        }
        return result
    }

    private static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

private struct FinanceSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    var isCount = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Spacer()
                    Text(title)
                        .font(.custom("SukhumvitSet-Medium", size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(isCount ? String(Int(amount)) : amount.formatted(.number.precision(.fractionLength(0))))
                    .font(.custom("SukhumvitSet-Bold", size: 21))
                    .foregroundStyle(.primary)
                if !isCount {
                    Text("บาท")
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PaymentRow: View {
    let payment: Payment
    let user: DormUser?
    let status: String
    let onMarkPaid: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch status {
        case "ชำระแล้ว": return .green
        case "ชำระบางส่วน": return .blue
        default: return .orange
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(payment.roomNumber)
                            .font(.custom("SukhumvitSet-Bold", size: 18))
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user?.firstName ?? "ลูกบ้าน") \(user?.lastName ?? "")")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                        Text(payment.method.isEmpty ? "ยังไม่ได้ระบุช่องทาง" : payment.method)
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                        Text(status)
                            .font(.custom("SukhumvitSet-Medium", size: 10))
                            .foregroundStyle(statusColor)
                        if payment.paymentPlan == "installment", payment.installmentPhase > 0 {
                            Text("งวด \(payment.installmentPhase)")
                                .font(.custom("SukhumvitSet-Medium", size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    if payment.paymentStatus != "paid" {
                        Button(action: onMarkPaid) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("รับชำระเต็มจำนวน")
                                    .font(.custom("SukhumvitSet-Bold", size: 12))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .opacity(0.75)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.78)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.green.opacity(0.22), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if payment.isDirty {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }
}

struct PaymentEditor: View {
    @Environment(\.dismiss) private var dismiss
    let users: [DormUser]
    let rooms: [Room]
    let roomTypes: [RoomType]
    let defaultMonth: String
    let onSave: (Payment) -> Void
    private let sourcePaymentPlan: String
    private let sourceInstallmentPhase: Int

    @State private var roomNumber: String
    @State private var month: String
    @State private var rentFee: String
    @State private var waterFee: String
    @State private var electricFee: String
    @State private var commonFee: String
    @State private var lateFee: String
    @State private var applianceFee: String
    @State private var paidAmount: String
    @State private var method: String
    @State private var slipPath: String
    @State private var dueDate: String
    @State private var paymentDate: String
    @State private var paymentStatus: String
    @State private var slipPaths: [String]
    @State private var selectedSlipItems: [PhotosPickerItem] = []
    @State private var isImportingSlip = false
    @State private var slipImportMessage: String?
    @State private var selectedDetent: PresentationDetent = .large

    private let statusOptions = [
        ("pending", "รอชำระ"),
        ("partial", "ชำระบางส่วน"),
        ("paid", "ชำระแล้ว")
    ]

    init(payment: Payment? = nil, users: [DormUser], rooms: [Room], roomTypes: [RoomType], defaultMonth: String, onSave: @escaping (Payment) -> Void) {
        self.users = users
        self.rooms = rooms
        self.roomTypes = roomTypes
        self.defaultMonth = defaultMonth
        self.onSave = onSave
        self.sourcePaymentPlan = payment?.paymentPlan ?? "monthly"
        self.sourceInstallmentPhase = payment?.installmentPhase ?? 0
        _roomNumber = State(initialValue: payment?.roomNumber ?? rooms.first?.roomNumber ?? users.first?.roomNumber ?? "")
        _month = State(initialValue: payment?.month ?? defaultMonth)
        _rentFee = State(initialValue: payment.map { String(format: "%.0f", $0.rentFee) } ?? "")
        _waterFee = State(initialValue: payment.map { String(format: "%.0f", $0.waterFee) } ?? "")
        _electricFee = State(initialValue: payment.map { String(format: "%.0f", $0.electricFee) } ?? "")
        _commonFee = State(initialValue: payment.map { String(format: "%.0f", $0.commonFee) } ?? "")
        _lateFee = State(initialValue: payment.map { String(format: "%.0f", $0.lateFee) } ?? "")
        _applianceFee = State(initialValue: payment.map { String(format: "%.0f", $0.applianceFee) } ?? "")
        _paidAmount = State(initialValue: payment.map { String(format: "%.0f", $0.paidAmount) } ?? "")
        _method = State(initialValue: payment?.method ?? "")
        let initialSlipPaths = Self.normalizedSlipPaths(from: payment)
        _slipPath = State(initialValue: initialSlipPaths.first ?? "")
        _slipPaths = State(initialValue: initialSlipPaths)
        _dueDate = State(initialValue: payment?.dueDate ?? "")
        _paymentDate = State(initialValue: payment?.paymentDate ?? "")
        _paymentStatus = State(initialValue: payment?.paymentStatus.isEmpty == false ? payment?.paymentStatus ?? "pending" : "pending")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PaymentEditorContextCard(
                        roomNumber: clean(roomNumber).isEmpty ? "-" : clean(roomNumber),
                        tenantName: selectedTenantName,
                        roomType: selectedRoomTypeName,
                        month: clean(month).isEmpty ? defaultMonth : clean(month),
                        planText: planText,
                        amount: totalAmount,
                        paidAmount: money(paidAmount),
                        status: statusTitle(for: paymentStatus),
                        statusColor: statusColor(for: paymentStatus),
                        slipCount: slipPaths.count
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

                Section {
                    if rooms.isEmpty {
                        labeledTextField("เลขห้อง", placeholder: "เช่น 101", text: $roomNumber)
                    } else {
                        Picker("ห้อง", selection: $roomNumber) {
                            ForEach(rooms) { room in
                                Text(room.roomNumber).tag(room.roomNumber)
                            }
                        }
                        .onChange(of: roomNumber) { _, _ in
                            applyRoomTypeDefaults(onlyWhenEmpty: true)
                        }
                        Button {
                            applyRoomTypeDefaults()
                        } label: {
                            Label("เติมราคาจากประเภทห้อง", systemImage: "wand.and.stars")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    labeledTextField("รอบเดือน", placeholder: "เช่น 2026-08", text: $month)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($month, maxLength: 7)
                    labeledTextField("วันครบกำหนด", placeholder: "เช่น 2026-08-31", text: $dueDate)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($dueDate)
                } header: {
                    formSectionHeader("ข้อมูลบิล", subtitle: "ระบุห้อง รอบเดือน และวันครบกำหนดของรายการนี้")
                }

                Section {
                    moneyField("ค่าเช่า", text: $rentFee)
                    moneyField("ค่าน้ำ", text: $waterFee)
                    moneyField("ค่าไฟ", text: $electricFee)
                    moneyField("ค่าส่วนกลาง", text: $commonFee)
                    moneyField("ค่าปรับล่าช้า", text: $lateFee)
                    moneyField("ค่าอุปกรณ์เสริม", text: $applianceFee)
                    HStack {
                        Text("ยอดรวม")
                        Spacer()
                        Text(totalAmount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .fontWeight(.semibold)
                    }
                } header: {
                    formSectionHeader("ยอดที่คิดเงิน", subtitle: "แก้เฉพาะยอดที่ต้องออกบิลให้ห้องนี้")
                }

                Section {
                    statusSelector
                    labeledTextField("ยอดที่ชำระแล้ว", placeholder: "0", text: $paidAmount)
                        .keyboardType(.decimalPad)
                        .decimalInput($paidAmount, maxIntegerDigits: 9, maxFractionDigits: 2)
                    labeledTextField("ช่องทางชำระเงิน", placeholder: "เช่น เงินสด หรือ โอนผ่านธนาคาร", text: $method)
                        .limitedText($method, maxLength: 60, trimNewlines: true)
                    labeledTextField("วันที่ชำระ", placeholder: "เช่น 2026-08-23", text: $paymentDate)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($paymentDate)
                    slipPickerContent
                } header: {
                    formSectionHeader("ผลการรับเงิน", subtitle: "อัปเดตสถานะ ช่องทางชำระ และหลักฐานสลิป")
                }
            }
            .navigationTitle("แก้ไขรายการชำระเงิน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let item = Payment(month: clean(month), amount: totalAmount)
                        item.roomNumber = clean(roomNumber)
                        if let tenant = users.first(where: { $0.roomNumber == item.roomNumber }) {
                            item.userId = tenant.serverId ?? Int(truncatingIfNeeded: tenant.id.hashValue)
                        } else {
                            item.userId = 0
                        }
                        item.rentFee = money(rentFee)
                        item.waterFee = money(waterFee)
                        item.electricFee = money(electricFee)
                        item.commonFee = money(commonFee)
                        item.lateFee = money(lateFee)
                        item.applianceFee = money(applianceFee)
                        item.paidAmount = paymentStatus == "paid" && money(paidAmount) == 0 ? totalAmount : money(paidAmount)
                        item.method = clean(method)
                        item.slipPath = slipPaths.first ?? clean(slipPath)
                        item.slipPathArray = slipPaths
                        item.dueDate = clean(dueDate)
                        item.paymentDate = clean(paymentDate)
                        item.paymentStatus = paymentStatus
                        item.paymentPlan = sourcePaymentPlan
                        item.installmentPhase = sourceInstallmentPhase
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(clean(roomNumber).isEmpty || clean(month).isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                applyRoomTypeDefaults(onlyWhenEmpty: true)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var statusSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("สถานะ")
                .font(.custom("SukhumvitSet-Medium", size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { value, title in
                    Button {
                        paymentStatus = value
                        if value == "paid", money(paidAmount) == 0 {
                            paidAmount = String(format: "%.0f", totalAmount)
                        } else if value == "pending" {
                            paidAmount = "0"
                        }
                    } label: {
                        Text(title)
                            .font(.custom("SukhumvitSet-Bold", size: 12))
                            .foregroundStyle(paymentStatus == value ? Color.white : Color.primary.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(paymentStatus == value ? Color.indigo : Color.primary.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var selectedTenant: DormUser? {
        users.first { clean($0.roomNumber) == clean(roomNumber) }
    }

    private var planText: String {
        if sourcePaymentPlan == "installment", sourceInstallmentPhase > 0 {
            return "ผ่อนชำระ งวด \(sourceInstallmentPhase)"
        }
        if sourcePaymentPlan == "booking" {
            return "รายการจอง/แรกเข้า"
        }
        return "บิลรายเดือน"
    }

    private var selectedTenantName: String {
        guard let selectedTenant else { return "ยังไม่พบลูกบ้านของห้องนี้" }
        let fullName = "\(selectedTenant.firstName) \(selectedTenant.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "ลูกบ้าน" : fullName
    }

    private var selectedRoomTypeName: String {
        guard let room = rooms.first(where: { clean($0.roomNumber) == clean(roomNumber) }) else {
            return "ยังไม่พบข้อมูลห้อง"
        }
        return room.roomType.isEmpty ? "ไม่ระบุประเภทห้อง" : room.roomType
    }

    private func statusTitle(for value: String) -> String {
        statusOptions.first { $0.0 == value }?.1 ?? "รอชำระ"
    }

    private func statusColor(for value: String) -> Color {
        switch value {
        case "paid": return .green
        case "partial": return .blue
        default: return .orange
        }
    }

    private func formSectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 14))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.custom("SukhumvitSet-Text", size: 11))
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var slipPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !slipImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(slipImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )

                                Button {
                                    removeSlip(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.black.opacity(0.55), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            PhotosPicker(selection: $selectedSlipItems, maxSelectionCount: 10, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    if isImportingSlip {
                        ProgressView()
                            .scaleEffect(0.82)
                    } else {
                        Image(systemName: slipPaths.isEmpty ? "photo.badge.plus" : "photo.on.rectangle")
                            .font(.system(size: 17, weight: .bold))
                    }

                    Text(slipPaths.isEmpty ? "เพิ่มรูปสลิป" : "เพิ่มรูปสลิปอีก")
                        .font(.custom("SukhumvitSet-Bold", size: 15))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isImportingSlip)

            if !slipPaths.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(slipImportMessage ?? "มีรูปสลิปแนบ \(slipPaths.count) รูป")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let slipImportMessage {
                Text(slipImportMessage)
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedSlipItems) { _, newItems in
            importSlipImages(newItems)
        }
    }

    private var slipImages: [UIImage] {
        slipPaths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }

    private var totalAmount: Double {
        money(rentFee) + money(waterFee) + money(electricFee) + money(commonFee) + money(lateFee) + money(applianceFee)
    }

    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        labeledTextField(title, placeholder: "0", text: text)
            .keyboardType(.decimalPad)
            .decimalInput(text, maxIntegerDigits: 9, maxFractionDigits: 2)
    }

    private func labeledTextField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.custom("SukhumvitSet-Medium", size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            TextField(placeholder, text: text)
                .font(.custom("SukhumvitSet-Text", size: 16))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.vertical, 6)
    }

    private func removeSlip(at index: Int) {
        guard slipPaths.indices.contains(index) else { return }
        slipPaths.remove(at: index)
        slipPath = slipPaths.first ?? ""
        slipImportMessage = slipPaths.isEmpty ? nil : "มีรูปสลิปแนบ \(slipPaths.count) รูป"
    }

    private func importSlipImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isImportingSlip = true
        slipImportMessage = nil

        Task {
            do {
                var imported: [String] = []
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        continue
                    }
                    imported.append(try SlipImageManager.saveImageData(data))
                }

                guard !imported.isEmpty else { throw CocoaError(.fileReadUnknown) }
                await MainActor.run {
                    slipPaths.append(contentsOf: imported)
                    slipPath = slipPaths.first ?? ""
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปแล้ว \(imported.count) รูป"
                }
            } catch {
                await MainActor.run {
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปไม่สำเร็จ"
                }
            }
        }
    }

    private func applyRoomTypeDefaults(onlyWhenEmpty: Bool = false) {
        if onlyWhenEmpty {
            let hasAnyManualFee = !rentFee.isEmpty || !waterFee.isEmpty || !electricFee.isEmpty || !commonFee.isEmpty
            guard !hasAnyManualFee else { return }
        }

        guard let room = rooms.first(where: { $0.roomNumber == roomNumber }),
              let type = roomTypes.first(where: { $0.name == room.roomType }) else { return }
        rentFee = String(format: "%.0f", type.price)
        waterFee = String(format: "%.0f", type.waterFee)
        electricFee = String(format: "%.0f", type.electricFee)
        commonFee = String(format: "%.0f", type.commonFee)
    }

    private func money(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSlipPaths(from payment: Payment?) -> [String] {
        guard let payment else { return [] }
        var paths = payment.slipPathArray
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }
        return paths
    }
}

private struct PaymentEditorContextCard: View {
    let roomNumber: String
    let tenantName: String
    let roomType: String
    let month: String
    let planText: String
    let amount: Double
    let paidAmount: Double
    let status: String
    let statusColor: Color
    let slipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 3) {
                    Text(roomNumber)
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(tenantName)
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Label(roomType, systemImage: "door.left.hand.open")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                    Label("รอบบิล \(month)", systemImage: "calendar")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                    Label(planText, systemImage: "doc.text")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                contextPill(title: "ยอดรวม", value: currency(amount), color: .indigo)
                contextPill(title: "ชำระแล้ว", value: currency(paidAmount), color: .green)
            }

            HStack(spacing: 8) {
                Label(status, systemImage: "circle.fill")
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(statusColor.opacity(0.12), in: Capsule())

                Label("\(slipCount) รูปสลิป", systemImage: "photo.on.rectangle")
                    .font(.custom("SukhumvitSet-Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func contextPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.custom("SukhumvitSet-Text", size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: "THB").precision(.fractionLength(0)))
    }
}
