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

    private var payments: [Payment] { allPayments.filter { !$0.isDeletedLocally } }
    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("บิลค่าใช้จ่าย")
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("สร้างและจัดการบิลจากข้อมูลในเครื่อง")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if payments.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", title: "ยังไม่มีข้อมูลบิล")
            } else {
                ForEach(payments) { payment in
                    BillRow(payment: payment, onEdit: {
                        editingPayment = payment
                    }, onDelete: {
                        deletingPayment = payment
                    })
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingEditor) {
            PaymentEditor(users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: currentMonthKey()) { payment in
                payment.isDirty = true
                payment.lastUpdated = Date()
                modelContext.insert(payment)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingPayment) { payment in
            PaymentEditor(payment: payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: payment.month) { draft in
                apply(draft, to: payment)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบบิลนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบบิลห้อง \(deletingPayment?.roomNumber ?? "")", role: .destructive) {
                guard let payment = deletingPayment else { return }
                payment.isDeletedLocally = true
                payment.isDirty = true
                payment.lastUpdated = Date()
                saveAndPush()
                deletingPayment = nil
            }
            Button("ยกเลิก", role: .cancel) { }
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
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
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
        payment.dueDate = draft.dueDate
        payment.paymentStatus = draft.paymentStatus
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
            print("Bill save error: \(error)")
        }
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}

private struct BillRow: View {
    let payment: Payment
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ห้อง \(payment.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                    Text("รอบบิล \(payment.month)")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                    Text(statusText)
                        .font(.custom("SukhumvitSet-Medium", size: 10))
                        .foregroundStyle(statusColor)
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
}
