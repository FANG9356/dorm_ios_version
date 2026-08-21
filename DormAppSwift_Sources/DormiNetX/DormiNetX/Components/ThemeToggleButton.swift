import SwiftUI

struct ThemeToggleButton: View {
    @AppStorage("appTheme") private var appTheme: Int = AppTheme.system.rawValue
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: cycleTheme) {
            ZStack {
                Circle() 
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                let currentTheme = AppTheme(rawValue: appTheme) ?? .system
                
                Image(systemName: currentTheme.iconName)
                    .font(.custom("SukhumvitSet-Text", size: 20))
                    .foregroundColor(currentTheme == .dark ? .yellow : .indigo)
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
    
    private func cycleTheme() {
        // Animate the icon transition
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 0.5
            rotation += 180
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let nextValue = (appTheme + 1) % AppTheme.allCases.count
            appTheme = nextValue
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                rotation += 180
            }
        }
    }
}
