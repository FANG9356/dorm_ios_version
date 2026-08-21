import SwiftUI

struct PricingTabView: View {
    var body: some View {
        VStack(spacing: 20) {

            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "tag.circle.fill")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.purple.opacity(0.7))
                    Text("ไม่มีข้อมูลการตั้งราคาในขณะนี้")
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
