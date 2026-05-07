import SwiftUI
import AppKit

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
            }

            VStack(spacing: 10) {
                Text("Welcome to Pace")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.black)

                Text("A reading focus tool for your Mac")
                    .font(.system(size: 18))
                    .foregroundColor(.black.opacity(0.55))
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
