import Foundation
import PostHog

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private var sessionStartTime: Date?
    private var modeStartTimes: [String: Date] = [:]
    private var currentMode: String?
    
    private init() {}
    
    func configure() {
        let apiKey = Config.posthogAPIKey
        let host = Config.posthogHost
        
        NSLog("🔧 Configuring PostHog...")
        NSLog("   API Key: \(apiKey.prefix(10))... (length: \(apiKey.count))")
        NSLog("   Host: \(host)")
        
        if apiKey.isEmpty {
            NSLog("❌ ERROR: PostHog API key is empty!")
            return
        }
        
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.debug = true  // Enable debug logging
        config.flushAt = 1   // Send events immediately (for testing)
        config.flushIntervalSeconds = 10  // Flush every 10 seconds
        
        PostHogSDK.shared.setup(config)
        
        // Identify the user with a persistent anonymous ID
        let userId = getOrCreateUserId()
        PostHogSDK.shared.identify(userId)
        NSLog("✅ PostHog configured successfully with user ID: \(userId)")
    }
    
    private func getOrCreateUserId() -> String {
        let key = "posthog_user_id"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        
        // Create a new anonymous user ID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    // MARK: - App Lifecycle Events
    
    func trackAppOpened() {
        sessionStartTime = Date()
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        let isNewUser = !hasSeenOnboarding
        
        NSLog("📊 Tracking: app_opened (new_user: \(isNewUser))")
        PostHogSDK.shared.capture("app_opened", properties: [
            "is_new_user": isNewUser
        ])
        PostHogSDK.shared.flush()  // Force immediate send
    }
    
    func trackAppClosed() {
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            PostHogSDK.shared.capture("app_closed", properties: [
                "session_duration_seconds": duration
            ])
        }
        PostHogSDK.shared.flush()
    }
    
    // MARK: - View Tracking
    
    func trackPaceViewShown() {
        NSLog("📊 Tracking: pace_view_shown")
        PostHogSDK.shared.capture("pace_view_shown")
        PostHogSDK.shared.flush()  // Force immediate send
    }
    
    func trackPaceViewHidden(duration: TimeInterval) {
        PostHogSDK.shared.capture("pace_view_hidden", properties: [
            "view_duration_seconds": duration
        ])
    }
    
    // MARK: - Mode Tracking
    
    func trackModeActivated(mode: String, size: String) {
        // End previous mode if exists
        if let prevMode = currentMode, let startTime = modeStartTimes[prevMode] {
            let duration = Date().timeIntervalSince(startTime)
            NSLog("📊 Tracking: mode_deactivated (\(prevMode))")
            PostHogSDK.shared.capture("mode_deactivated", properties: [
                "mode": prevMode,
                "duration_seconds": duration
            ])
        }
        
        // Start new mode
        currentMode = mode
        modeStartTimes[mode] = Date()
        
        NSLog("📊 Tracking: mode_activated (\(mode), \(size))")
        PostHogSDK.shared.capture("mode_activated", properties: [
            "mode": mode,
            "size": size
        ])
        PostHogSDK.shared.flush()  // Force immediate send
    }
    
    func trackModeDeactivated(mode: String) {
        if let startTime = modeStartTimes[mode] {
            let duration = Date().timeIntervalSince(startTime)
            PostHogSDK.shared.capture("mode_deactivated", properties: [
                "mode": mode,
                "duration_seconds": duration
            ])
            modeStartTimes.removeValue(forKey: mode)
        }
        currentMode = nil
    }
    
    // MARK: - Focus Mode Tracking
    
    func trackFocusModeShown() {
        PostHogSDK.shared.capture("focus_mode_shown")
    }
    
    func trackFocusModeHidden(duration: TimeInterval) {
        PostHogSDK.shared.capture("focus_mode_hidden", properties: [
            "duration_seconds": duration
        ])
    }
    
    // MARK: - Flash Mode Tracking
    
    func trackFlashModeToggled(isActive: Bool) {
        PostHogSDK.shared.capture("flash_mode_toggled", properties: [
            "is_active": isActive
        ])
    }
    
    func trackFlashTriggered() {
        PostHogSDK.shared.capture("flash_triggered")
    }
    
    // MARK: - Onboarding Tracking
    
    func trackOnboardingCompleted() {
        NSLog("📊 Tracking: onboarding_completed")
        PostHogSDK.shared.capture("onboarding_completed")
        PostHogSDK.shared.flush()  // Force immediate send
    }
}
