import SwiftUI

struct HowToUseScreen: View {
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Text("How it works")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
            
            // Placeholder for animated GIF
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 480, height: 280)
                
                VStack(spacing: 10) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 60))
                        .foregroundColor(.black.opacity(0.8))
                    
                    Text("[Mouse Movement GIF Here]")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.4))
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
