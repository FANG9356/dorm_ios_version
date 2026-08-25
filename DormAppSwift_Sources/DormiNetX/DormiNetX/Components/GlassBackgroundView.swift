import SwiftUI

struct GlassBackgroundView: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(AppBackgroundManager.kindKey) private var customBackgroundKind = AppBackgroundKind.system.rawValue
    @AppStorage(AppBackgroundManager.fileNameKey) private var customBackgroundFileName = ""
    @AppStorage(AppBackgroundManager.updateTokenKey) private var customBackgroundUpdateToken = ""
    
    var body: some View {
        ZStack {
            if let customBackground = activeCustomBackground {
                customBackgroundView(customBackground)
            } else {
                systemBackground
            }
        }
        .id(customBackgroundUpdateToken)
        .animation(.easeInOut(duration: 0.8), value: colorScheme)
        .animation(.easeInOut(duration: 0.35), value: customBackgroundKind)
        .onAppear {
            startSystemBackgroundAnimation()
        }
        .onChange(of: customBackgroundKind) { _, newValue in
            guard newValue == AppBackgroundKind.system.rawValue else { return }
            restartSystemBackgroundAnimation()
        }
    }

    private var activeCustomBackground: (kind: AppBackgroundKind, url: URL)? {
        guard let kind = AppBackgroundKind(rawValue: customBackgroundKind),
              kind != .system,
              let url = AppBackgroundManager.url(for: customBackgroundFileName),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return (kind, url)
    }

    @ViewBuilder
    private func customBackgroundView(_ background: (kind: AppBackgroundKind, url: URL)) -> some View {
        GeometryReader { geometry in
            ZStack {
                switch background.kind {
                case .image:
                    if let image = UIImage(contentsOfFile: background.url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        systemBackground
                    }
                case .video:
                    LoopingBackgroundVideoView(url: background.url)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                case .system:
                    systemBackground
                }

                Rectangle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.18))

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(colorScheme == .dark ? 0.74 : 0.48)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var systemBackground: some View {
        ZStack {
            if colorScheme == .dark {
                // Dark Theme: Navy Base
                Color(red: 0.1, green: 0.1, blue: 0.15).ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 300, height: 300)
                            .blur(radius: 60)
                            .offset(x: isAnimating ? geometry.size.width / 2 : -geometry.size.width / 2,
                                    y: isAnimating ? geometry.size.height / 2 : -geometry.size.height / 2)
                        
                        Circle()
                            .fill(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 250, height: 250)
                            .blur(radius: 50)
                            .offset(x: isAnimating ? -geometry.size.width / 3 : geometry.size.width / 3,
                                    y: isAnimating ? -geometry.size.height / 3 : geometry.size.height / 3)
                    }
                }
                .ignoresSafeArea()
                
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            } else {
                // Light Theme: White Base
                Color.white.ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 1.0).opacity(0.6), Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 350, height: 350)
                            .blur(radius: 80)
                            .offset(x: isAnimating ? geometry.size.width / 2 : -geometry.size.width / 4,
                                    y: isAnimating ? geometry.size.height / 3 : -geometry.size.height / 4)
                        
                        Circle()
                            .fill(LinearGradient(colors: [Color(red: 0.8, green: 0.4, blue: 1.0).opacity(0.5), Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.5)], startPoint: .bottomLeading, endPoint: .topTrailing))
                            .frame(width: 300, height: 300)
                            .blur(radius: 60)
                            .offset(x: isAnimating ? -geometry.size.width / 4 : geometry.size.width / 2,
                                    y: isAnimating ? -geometry.size.height / 4 : geometry.size.height / 3)
                    }
                }
                .ignoresSafeArea()
                
                Color.white.opacity(0.15)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        }
    }

    private func startSystemBackgroundAnimation() {
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }

    private func restartSystemBackgroundAnimation() {
        isAnimating = false
        DispatchQueue.main.async {
            startSystemBackgroundAnimation()
        }
    }
}
