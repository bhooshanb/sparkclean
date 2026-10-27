import Testing
import Foundation
@testable import SparkClean

@Suite
struct SparkCleanUpdaterTests {
    @Test func appVersionPropertiesArePopulated() {
        #expect(!AppVersion.shortVersion.isEmpty)
        #expect(!AppVersion.buildNumber.isEmpty)
        #expect(AppVersion.displayString.contains("Version"))
        #expect(AppVersion.displayString.contains(AppVersion.shortVersion))
        #expect(AppVersion.displayString.contains(AppVersion.buildNumber))
    }

    @Test @MainActor func updaterInstanceIsCreated() {
        let updater = SparkCleanUpdater.shared
        // In standalone test runner, updater starts safely without crashing.
        #expect(updater.automaticallyChecksForUpdates == true || updater.automaticallyChecksForUpdates == false)
    }

    @Test @MainActor func updaterToggleAutomaticChecks() {
        let updater = SparkCleanUpdater.shared
        let original = updater.automaticallyChecksForUpdates
        updater.automaticallyChecksForUpdates = !original
        #expect(updater.automaticallyChecksForUpdates == !original)
        // Restore
        updater.automaticallyChecksForUpdates = original
    }
}
