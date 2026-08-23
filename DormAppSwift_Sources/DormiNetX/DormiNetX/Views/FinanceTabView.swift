import SwiftUI
import SwiftData

struct FinanceTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @State private var selectedMonth = Date()
    @State private var selectedStatus = "ทั้งหมด"
    @State private var searchText = ""

    private let statuses = ["ทั้งหมด", "ชำระแล้ว", "รอชำระ", "ชำระบางส่วน"]

    var body: some View {
        VStack(spacing: 16) {
            header
            summaryGrid
            filters
            paymentList
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("การเงินและชำระเงิน")
                    .font(.custom("SukhumvitSet-Bold", size: 24))
                    .foregroundStyle(.primary)
                Text("บันทึกรายการไว้ในเครื่อง และซิงค์เมื่อพร้อม")
                    .font(.custom("SukhumvitSet-Text", size: 12))
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
            let user = users.first { $0.serverId == payment.userId }
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
                    PaymentRow(payment: payment, user: users.first { $0.serverId == payment.userId }, status: statusLabel(for: payment))
                }
            }
        }
    }

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: selectedMonth)
    }

    private func statusLabel(for payment: Payment) -> String {
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "ชำระบางส่วน"
        default: return "รอชำระ"
        }
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

    private var statusColor: Color {
        switch status {
        case "ชำระแล้ว": return .green
        case "ชำระบางส่วน": return .blue
        default: return .orange
        }
    }

    var body: some View {
        GlassCard {
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
                }
            }
        }
    }
}

