import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var currentPage: Int
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(spacing: 0) {
                // Content area with padding to prevent cutoff
                ZStack {
                    if currentPage == 1 {
                        WelcomeScreen()
                            .transition(.opacity)
                    } else if currentPage == 2 {
                        HowToUseScreen()
                            .transition(.opacity)
                    } else if currentPage == 3 {
                        FeaturesScreen()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 20) // Add padding to prevent content cutoff
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentPage > 1 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Back")
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(minWidth: 100, minHeight: 40)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        // Spacer to maintain layout when Back button is hidden
                        Spacer()
                            .frame(width: 100)
                    }
                    
                    Spacer()
                    
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(1...3, id: \.self) { page in
                            Circle()
                                .fill(page == currentPage ? Color.black : Color.black.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPage < 3 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            // Mark onboarding as complete and close
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            AnalyticsManager.shared.trackOnboardingCompleted()
                            onComplete()
                        }
                    }) {
                        Text(currentPage == 3 ? "Get Started" : "Next")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .frame(minWidth: 120, minHeight: 40)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
    }
}
