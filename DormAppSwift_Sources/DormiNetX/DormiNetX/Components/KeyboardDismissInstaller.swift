import SwiftUI
import UIKit

struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private weak var tapRecognizer: UITapGestureRecognizer?

        func installIfNeeded(from view: UIView) {
            guard let window = view.window else { return }
            if installedWindow === window, tapRecognizer != nil { return }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            installedWindow = window
            tapRecognizer = recognizer
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !isInteractiveInput(touch.view)
        }

        private func isInteractiveInput(_ view: UIView?) -> Bool {
            guard let view else { return false }
            if view is UIControl || view is UITextView {
                return true
            }
            return isInteractiveInput(view.superview)
        }
    }
}

extension View {
    func globalKeyboardDismiss() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}
