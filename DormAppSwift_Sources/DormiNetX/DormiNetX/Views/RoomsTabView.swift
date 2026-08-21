import SwiftUI

struct RoomsTabView: View {
    var body: some View {
        VStack(spacing: 20) {

            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "door.left.hand.open")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.indigo.opacity(0.7))
                    Text("ไม่มีข้อมูลห้องพักในขณะนี้")
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
