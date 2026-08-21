import SwiftUI

struct BillsTabView: View {
    var body: some View {
        VStack(spacing: 20) {

            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.orange.opacity(0.7))
                    Text("ไม่มีบิลค่าใช้จ่ายในขณะนี้")
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
