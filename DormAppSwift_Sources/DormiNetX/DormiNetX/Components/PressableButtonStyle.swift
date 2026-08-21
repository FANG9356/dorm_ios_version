import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.2), value: configuration.isPressed)
    }
}
