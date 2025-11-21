import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Placeholder for animated GIF/image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 400, height: 300)
                
                VStack(spacing: 10) {
                    Image(systemName: "flashlight.on.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("[Animated GIF Here]")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Text("Welcome to Pace")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
            
            Text("A reading focus tool for macOS")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
