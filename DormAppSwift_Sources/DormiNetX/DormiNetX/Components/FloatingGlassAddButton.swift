import SwiftUI

struct FloatingGlassAddButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void
    var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 58, height: 58)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .indigo.opacity(0.28), .white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12), radius: 12, x: 0, y: 6)
                .rotationEffect(.degrees(rotation))
                .symbolEffect(.bounce, value: rotation)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("เพิ่มข้อมูล")
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
            .scrollDismissesKeyboard(.immediately)
    }

    func iphoneSheetStyle() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
    }

    func iphoneFullSheetStyle() -> some View {
        presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
    }
}