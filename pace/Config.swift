import Foundation

enum Config {
    // Read from Config.plist file
    static var posthogAPIKey: String {
        // First try Info.plist (if xcconfig is set up)
        if let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String, 
           !key.isEmpty,
           !key.contains("$(") {  // Check it's not an unresolved variable
            NSLog("✅ Using PostHog API key from Info.plist")
            return key
        }
        
        // Fallback to Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["POSTHOG_API_KEY"] as? String,
           !key.isEmpty {
            NSLog("✅ Using PostHog API key from Config.plist")
            return key
        }
        
        NSLog("❌ ERROR: PostHog API key not found in Info.plist or Config.plist!")
        return ""
    }
    
    static var posthogHost: String {
        // First try Info.plist
        if let host = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String, 
           !host.isEmpty,
           !host.contains("$(") {  // Check it's not an unresolved variable
            return host
        }
        
        // Fallback to Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let host = dict["POSTHOG_HOST"] as? String,
           !host.isEmpty {
            return host
        }
        
        NSLog("⚠️ Using default PostHog host")
        return "https://us.i.posthog.com"
    }
}
