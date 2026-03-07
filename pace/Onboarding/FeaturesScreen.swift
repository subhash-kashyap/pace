import SwiftUI

struct FeaturesScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Click on the white bar on the right edge of your screen.")
                .font(.system(size: 32, weight: .bold)) // Slightly smaller to fit if needed
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "sidebar.right",
                    title: "Open Side Menu",
                    description: "Hover over the right-middle edge of your screen."
                )
                FeatureRow(
                    icon: "power",
                    title: "Turn On Pace",
                    description: "Click 'Turn On' in the menu to see the spotlight."
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
            
            // Visual hint
            HStack(spacing: 15) {
                Text("Look for the thin white bar on the right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.5))
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black.opacity(0.7))
            }
            .padding(.bottom, 20)
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
