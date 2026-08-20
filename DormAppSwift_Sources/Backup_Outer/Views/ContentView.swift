import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    
    var body: some View {
        ZStack {
            if isLoggedIn {
                RoomListView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity
                    ))
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 1.04))
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isLoggedIn)
    }
}
