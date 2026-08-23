import SwiftUI
import SwiftData

struct TransfersTabView: View {
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]

    private var paymentsWithEvidence: [Payment] {
        payments.filter { !$0.slipPath.isEmpty || !$0.slipPathArray.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("หลักฐานการโอน")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("หลักฐานที่บันทึกไว้ในเครื่อง")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if paymentsWithEvidence.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีหลักฐานการโอน")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(paymentsWithEvidence) { payment in
                    GlassCard {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ห้อง \(payment.roomNumber)")
                                    .font(.custom("SukhumvitSet-Bold", size: 15))
                                Text("รอบบิล \(payment.month)")
                                    .font(.custom("SukhumvitSet-Text", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(payment.paymentStatus == "paid" ? "ตรวจแล้ว" : "รอตรวจ")
                                .font(.custom("SukhumvitSet-Medium", size: 10))
                                .foregroundStyle(payment.paymentStatus == "paid" ? .green : .orange)
                        }
                    }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
    }
}
