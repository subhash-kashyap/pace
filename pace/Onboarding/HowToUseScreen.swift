import SwiftUI
import AVKit

struct HowToUseScreen: View {
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Text("How it works")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
            
            // Video player
            if let videoURL = Bundle.main.url(forResource: "PaceFeatureOnbVid", withExtension: "mp4") {
                LoopingVideoPlayer(url: videoURL)
                    .frame(width: 480, height: 280)
                    .cornerRadius(12)
            } else {
                // Fallback if video not found
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 480, height: 280)
                    
                    VStack(spacing: 10) {
                        Image(systemName: "cursorarrow.rays")
                            .font(.system(size: 60))
                            .foregroundColor(.black.opacity(0.8))
                        
                        Text("[Video not found]")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.4))
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("Move your mouse to guide the focus spotlight.")
                    .font(.system(size: 18))
                    .foregroundColor(.black.opacity(0.8))
                
                Text("Click the menu bar icon to change modes.")
                    .font(.system(size: 18))
                    .foregroundColor(.black.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct LoopingVideoPlayer: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Use resize aspect to fit the width, then align to top
        playerLayer.videoGravity = .resizeAspect
        
        view.wantsLayer = true
        view.layer?.addSublayer(playerLayer)
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        // Auto-play and mute
        player.isMuted = true
        player.play()
        
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        context.coordinator.containerView = view
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            // Calculate frame to show top of video (menu bar area)
            let viewBounds = nsView.bounds
            let videoAspect: CGFloat = 1280.0 / 720.0  // 16:9
            let viewAspect = viewBounds.width / viewBounds.height
            
            if videoAspect > viewAspect {
                // Video is wider - fit to width, align to top
                let scaledHeight = viewBounds.width / videoAspect
                playerLayer.frame = CGRect(
                    x: 0,
                    y: viewBounds.height - scaledHeight,  // Align to top
                    width: viewBounds.width,
                    height: scaledHeight
                )
            } else {
                // Video is taller - fit to height
                let scaledWidth = viewBounds.height * videoAspect
                playerLayer.frame = CGRect(
                    x: (viewBounds.width - scaledWidth) / 2,
                    y: 0,
                    width: scaledWidth,
                    height: viewBounds.height
                )
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var containerView: NSView?
    }
}
