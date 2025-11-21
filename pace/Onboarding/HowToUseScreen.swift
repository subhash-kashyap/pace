import SwiftUI
import AVKit
import AVFoundation

struct HowToUseScreen: View {
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Text("How it works")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
            
            // Video player
            if let videoURL = Bundle.main.url(forResource: "PaceFeatureOnbVid", withExtension: "mp4") {
                SimpleVideoPlayer(url: videoURL)
                    .frame(width: 600, height: 350)
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 600, height: 350)
                    
                    Text("Video not found")
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            
            VStack(spacing: 12) {
                Text("Move your mouse to guide the focus area.")
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

struct SimpleVideoPlayer: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> NSView {
        print("🎬 makeNSView called")
        print("📹 Video URL: \(url.path)")
        
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        print("✅ View created with layer")
        
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.clear.cgColor
        playerLayer.frame = CGRect(x: 0, y: 0, width: 600, height: 350)
        
        print("📐 Initial playerLayer frame: \(playerLayer.frame)")
        
        view.layer?.addSublayer(playerLayer)
        
        print("✅ PlayerLayer added to view")
        
        player.isMuted = true
        player.play()
        
        print("▶️ Player started")
        
        // Loop
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            print("🔄 Video ended, looping")
            player.seek(to: .zero)
            player.play()
        }
        
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let playerLayer = context.coordinator.playerLayer else { return }
        
        // Only update if bounds are valid (not zero)
        if nsView.bounds.width > 0 && nsView.bounds.height > 0 {
            print("🔄 updateNSView: updating frame to \(nsView.bounds)")
            playerLayer.frame = nsView.bounds
        } else {
            print("⚠️ updateNSView: skipping zero bounds")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
    }
}
