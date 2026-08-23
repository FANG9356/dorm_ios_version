import SwiftUI
import SwiftData

struct BillsTabView: View {
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("บิลค่าใช้จ่าย")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("ข้อมูลจากการบันทึกในเครื่อง")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if payments.isEmpty {
                emptyState(icon: "doc.text.magnifyingglass", title: "ยังไม่มีข้อมูลบิล")
            } else {
                ForEach(payments) { payment in
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
                            Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                                .font(.custom("SukhumvitSet-Bold", size: 15))
                        }
                }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
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
}
