import AVFoundation
import SwiftUI
import UIKit

struct LoopingBackgroundVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingVideoPlayerView {
        let view = LoopingVideoPlayerView()
        view.configure(url: url)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoPlayerView, context: Context) {
        uiView.configure(url: url)
    }

    static func dismantleUIView(_ uiView: LoopingVideoPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LoopingVideoPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var currentURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    func configure(url: URL) {
        guard currentURL != url else {
            player?.play()
            return
        }

        currentURL = url
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none

        let playerLayer = layer as? AVPlayerLayer
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.player = queuePlayer

        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        player = queuePlayer
        queuePlayer.play()
    }

    func stop() {
        player?.pause()
        player = nil
        looper = nil
        currentURL = nil
    }
}
