import Foundation
import Sparkle

/// Owns the Sparkle updater (`SPUStandardUpdaterController`), starts it with
/// the app, and exposes publishable state so menu items and Settings react live.
///
/// Configuration lives in Info.plist:
/// - `SUFeedURL` — the appcast (must be HTTPS).
/// - `SUPublicEDKey` — EdDSA public key from Sparkle's `generate_keys`.
/// - `SUEnableAutomaticChecks` — opt out of Sparkle's permission prompt.
@MainActor
final class SparkCleanUpdater: ObservableObject {
    static let shared = SparkCleanUpdater()

    private let controller: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?
    private var autoCheckObservation: NSKeyValueObservation?

    /// True when running within a configured macOS application bundle.
    let isAvailable: Bool

    /// False while Sparkle is already checking or downloading, so UI can disable
    /// the "Check for Updates…" item.
    @Published private(set) var canCheckForUpdates = false

    /// Whether automatic background update checks are enabled.
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet {
            guard isAvailable, controller.updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates else { return }
            controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    /// Date of the most recent update check, if any.
    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    private init() {
        // Sparkle expects to run inside an app bundle with SUFeedURL configured.
        let isConfiguredBundle = Bundle.main.bundleIdentifier != nil &&
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        self.isAvailable = isConfiguredBundle

        controller = SPUStandardUpdaterController(
            startingUpdater: isConfiguredBundle,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates

        // Observe `canCheckForUpdates` live via KVO
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
            let can = updater.canCheckForUpdates
            Task { @MainActor in
                self?.canCheckForUpdates = can
            }
        }
        canCheckForUpdates = controller.updater.canCheckForUpdates

        // Observe `automaticallyChecksForUpdates` live via KVO
        autoCheckObservation = controller.updater.observe(\.automaticallyChecksForUpdates) { [weak self] updater, _ in
            let auto = updater.automaticallyChecksForUpdates
            Task { @MainActor in
                if self?.automaticallyChecksForUpdates != auto {
                    self?.automaticallyChecksForUpdates = auto
                }
            }
        }
    }

    /// Manual "Check for Updates…" action (menu / Settings button).
    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }
}
