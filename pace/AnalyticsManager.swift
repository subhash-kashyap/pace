import Foundation
import PostHog

class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private var sessionStartTime: Date?
    private var modeStartTimes: [String: Date] = [:]
    private var currentMode: String?
    
    private init() {}
    
    func configure() {
        let config = PostHogConfig(apiKey: Config.posthogAPIKey, host: Config.posthogHost)
        PostHogSDK.shared.setup(config)
    }
    
    // MARK: - App Lifecycle Events
    
    func trackAppOpened() {
        sessionStartTime = Date()
        PostHogSDK.shared.capture("app_opened")
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
        PostHogSDK.shared.capture("pace_view_shown")
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
            PostHogSDK.shared.capture("mode_deactivated", properties: [
                "mode": prevMode,
                "duration_seconds": duration
            ])
        }
        
        // Start new mode
        currentMode = mode
        modeStartTimes[mode] = Date()
        
        PostHogSDK.shared.capture("mode_activated", properties: [
            "mode": mode,
            "size": size
        ])
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
}
