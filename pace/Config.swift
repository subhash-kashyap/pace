import Foundation

enum Config {
    // Read from Config.plist file
    static var posthogAPIKey: String {
        // First try Info.plist (if xcconfig is set up)
        if let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String, !key.isEmpty {
            return key
        }
        
        // Fallback to Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let key = dict["POSTHOG_API_KEY"] as? String {
            return key
        }
        
        print("⚠️ PostHog API key not found!")
        return ""
    }
    
    static var posthogHost: String {
        // First try Info.plist
        if let host = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String, !host.isEmpty {
            return host
        }
        
        // Fallback to Config.plist
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let host = dict["POSTHOG_HOST"] as? String {
            return host
        }
        
        return "https://us.i.posthog.com"
    }
}
