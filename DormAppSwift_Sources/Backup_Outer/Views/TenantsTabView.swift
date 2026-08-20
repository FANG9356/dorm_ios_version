import SwiftUI

struct TenantsTabView: View {
    var body: some View {
        VStack(spacing: 20) {

            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "person.3.fill")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.blue.opacity(0.7))
                    Text("ไม่มีข้อมูลลูกบ้านในขณะนี้")
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
