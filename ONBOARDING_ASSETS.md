# Onboarding Assets Guide

## Required Assets

The onboarding flow uses placeholder images that need to be replaced with actual GIFs/images.

### Screen 1: Welcome
- **Location**: `WelcomeScreen` in `pace/OnboardingView.swift`
- **Current**: SF Symbol icon placeholder
- **Needed**: Animated GIF showing the overlay in action (cycling through different modes)
- **Recommended size**: 400x300 points
- **Format**: GIF or video (use `AnimatedImage` from SDWebImage or similar)

### Screen 2: How to Use
- **Location**: `HowToUseScreen` in `pace/OnboardingView.swift`
- **Current**: SF Symbol icon placeholder
- **Needed**: Animated GIF showing mouse movement with overlay following
- **Recommended size**: 500x300 points
- **Format**: GIF or video

### Screen 3: Features
- **Location**: `FeaturesScreen` in `pace/OnboardingView.swift`
- **Current**: Text-only with SF Symbol arrow
- **Needed**: Small image/screenshot of the menu bar with features highlighted
- **Recommended size**: Small, just enough to show the menu bar icon
- **Format**: PNG or static image

## How to Add Assets

1. Add your GIF/image files to the Xcode project (drag into `pace/Assets.xcassets`)
2. Replace the placeholder `ZStack` blocks in `OnboardingView.swift` with:

```swift
// For static images:
Image("your-asset-name")
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(width: 400, height: 300)
    .cornerRadius(12)

// For GIFs, you'll need to add a package like SDWebImage:
// https://github.com/SDWebImage/SDWebImage
```

## Testing the Onboarding

The onboarding only shows on first launch. To test it again:

```bash
# Reset the onboarding flag
defaults delete synw.pace hasSeenOnboarding

# Or reset all app preferences
defaults delete synw.pace
```

Then relaunch the app.

## Accessing Onboarding After First Launch

Users can always access the onboarding again via:
**Menu Bar Icon → Extras → How to Use**
