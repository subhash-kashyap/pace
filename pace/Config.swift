import Foundation

enum Config {
    // Read from Info.plist which gets values from xcconfig
    static var posthogAPIKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String ?? ""
    }
    
    static var posthogHost: String {
        return Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String ?? "https://us.i.posthog.com"
    }
}
