import Foundation

/// Centralized access to the app's version and build number.
public enum AppVersion {
    /// The marketing version (e.g. "1.0.0" from CFBundleShortVersionString).
    public static var shortVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    /// The build number (e.g. "11" from CFBundleVersion).
    public static var buildNumber: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }

    /// User-facing display string (e.g. "Version 1.0.0 (11)").
    public static var displayString: String {
        "Version \(shortVersion) (Build \(buildNumber))"
    }
}
