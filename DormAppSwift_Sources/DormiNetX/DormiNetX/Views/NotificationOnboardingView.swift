import SwiftUI

struct NotificationOnboardingView: View {
    @AppStorage("hasSeenNotificationOnboarding") private var hasSeenNotificationOnboarding = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var notificationManager = NotificationManager()
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateIcon ? 1.1 : 0.9)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateIcon)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)
                    .rotationEffect(.degrees(animateIcon ? 10 : -10))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animateIcon)
            }
            .padding(.bottom, 40)
            
            // Text
            Text("ไม่พลาดทุกความเคลื่อนไหว")
                .font(.custom("SukhumvitSet-Bold", size: 28))
                .foregroundColor(.primary)
                .padding(.bottom, 12)
            
            Text("เปิดรับการแจ้งเตือน เพื่อรับรู้สถานะห้องพัก\nใบแจ้งหนี้ และอัปเดตงานแจ้งซ่อมได้ทันที")
                .font(.custom("SukhumvitSet-Medium", size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            
            // Info Rows
            VStack(alignment: .leading, spacing: 24) {
                InfoRow(icon: "doc.text.fill", color: .blue, title: "บิลค่าเช่า", subtitle: "แจ้งเตือนเมื่อมีการออกบิลใหม่")
                InfoRow(icon: "wrench.and.screwdriver.fill", color: .orange, title: "งานแจ้งซ่อม", subtitle: "อัปเดตสถานะการซ่อมรวดเร็วทันใจ")
                InfoRow(icon: "person.fill.checkmark", color: .green, title: "ข้อมูลลูกบ้าน", subtitle: "แจ้งเตือนเมื่อสัญญาเช่าใกล้หมดอายุ")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 16) {
                Button(action: {
                    notificationManager.requestPermission { granted in
                        hasSeenNotificationOnboarding = true
                        dismiss()
                    }
                }) {
                    Text("เปิดใช้งานการแจ้งเตือน")
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: .indigo.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                Button(action: {
                    hasSeenNotificationOnboarding = true
                    dismiss()
                }) {
                    Text("ไว้ทีหลัง")
                        .font(.custom("SukhumvitSet-Bold", size: 16))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground))
        .onAppear {
            animateIcon = true
            notificationManager.checkPermissionStatus()
        }
    }
}

fileprivate struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.custom("SukhumvitSet-Text", size: 14))
                    .foregroundColor(.secondary)
            }
        }
    }
}
