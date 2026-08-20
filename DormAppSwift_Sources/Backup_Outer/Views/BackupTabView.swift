import SwiftUI

struct BackupTabView: View {
    var body: some View {
        VStack(spacing: 20) {
            
            GlassCard {
                VStack(spacing: 15) {
                    Image(systemName: "externaldrive.badge.icloud.fill")
                        .font(.custom("SukhumvitSet-Text", size: 50))
                        .foregroundColor(.indigo)
                    Text("ระบบสำรองและกู้คืนข้อมูลอยู่ระหว่างการพัฒนา")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
            
            Spacer()
        }
        .padding(.top, 90)
        .padding(.horizontal, 20)
    }
}
