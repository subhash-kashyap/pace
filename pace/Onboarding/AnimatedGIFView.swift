import SwiftUI
import AppKit
import ImageIO

struct AnimatedGIFView: NSViewRepresentable {
    let imageSource: CGImageSource
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        
        // Create animated image from GIF source
        if let image = createAnimatedImage(from: imageSource) {
            imageView.image = image
        }
        
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        // No updates needed
    }
    
    private func createAnimatedImage(from source: CGImageSource) -> NSImage? {
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }
        
        var images: [NSImage] = []
        var totalDuration: TimeInterval = 0
        
        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            
            let nsImage = NSImage(cgImage: cgImage, size: .zero)
            images.append(nsImage)
            
            // Get frame duration
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
               let duration = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double {
                totalDuration += duration
            } else {
                totalDuration += 0.1 // Default duration
            }
        }
        
        guard let firstImage = images.first else { return nil }
        
        // Create animated image
        let animatedImage = NSImage(size: firstImage.size)
        animatedImage.addRepresentations(images.flatMap { $0.representations })
        
        return animatedImage
    }
}
