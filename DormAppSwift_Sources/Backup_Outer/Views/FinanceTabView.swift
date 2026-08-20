import SwiftUI

struct FinanceTabView: View {
    var body: some View {
        VStack(spacing: 20) {

            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "dollarsign.arrow.circlepath")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.green.opacity(0.7))
                    Text("ไม่มีข้อมูลการเงินในขณะนี้")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .padding()
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.top, 110)
    }
}
