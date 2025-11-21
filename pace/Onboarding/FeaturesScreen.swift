import SwiftUI

struct FeaturesScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Everything you need")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "rectangle",
                    title: "4 Focus Modes",
                    description: "Rectangle, Center Column, Square, and Circle"
                )
                FeatureRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Adjustable Sizes",
                    description: "Small, Medium, and Large options"
                )
                FeatureRow(
                    icon: "doc.text",
                    title: "Focus Message",
                    description: "Distraction-free writing environment"
                )
                FeatureRow(
                    icon: "timer",
                    title: "Flash Mode",
                    description: "25-minute Pomodoro timer with alerts"
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Menu bar reference
            HStack(spacing: 10) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.white.opacity(0.6))
                Text("Find all features in the menu bar")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
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
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}
