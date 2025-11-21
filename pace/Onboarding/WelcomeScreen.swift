import SwiftUI

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Welcome to Pace")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.black)
            
            Text("A focus tool for reading long texts")
                .font(.system(size: 18))
                .foregroundColor(.black.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
