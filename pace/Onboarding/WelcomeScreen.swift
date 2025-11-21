import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Placeholder for animated GIF/image
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 400, height: 300)
                
                VStack(spacing: 10) {
                    Image(systemName: "flashlight.on.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text("[A focus tool for reading long texts]")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.4))
                }
            }
            
            Text("Welcome to Pace")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.black)
            
            Text("A reading focus tool for macOS")
                .font(.system(size: 18))
                .foregroundColor(.black.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
