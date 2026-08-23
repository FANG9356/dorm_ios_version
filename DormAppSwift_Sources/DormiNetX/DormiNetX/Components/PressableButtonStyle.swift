import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.68, blendDuration: 0.2), value: configuration.isPressed)
    }
}
