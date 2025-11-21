import SwiftUI

struct FeaturesScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Pace is in the menubar tray on top of your screen. It has")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "rectangle",
                    title: "4 Modes of Spotlight",
                    description: "Rectangle, Center Column, Square, and Circle"
                )
                FeatureRow(
                    icon: "doc.text",
                    title: "Focus Message",
                    description: "Distraction-free black and white space"
                )
                FeatureRow(
                    icon: "timer",
                    title: "Flash blinker",
                    description: "Every 25-minutes screen boundary flashs. I use it to breathe out."
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Menu bar reference
            HStack(spacing: 10) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.black.opacity(0.6))
                Text("Again, this app lives in your menubar tray on top, including this.")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.7))
            }
        }
    }
}
