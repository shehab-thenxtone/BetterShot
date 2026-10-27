import AppKit
import BetterShotCore
import BetterShotServices
import Observation
import OSLog

/// Everything behind the cloud button (requirements §4.9): which accounts are linked, linking them from
/// Preferences, uploading to a file host and copying its link, and handing an image to a chat app.
@MainActor
@Observable
final class DestinationsCenter {
    private(set) var linkedProviders: Set<CloudProvider>
    /// Providers with a client ID, bundled with the build or entered by the user.
    private(set) var configuredProviders: Set<CloudProvider>
    private(set) var linkingProvider: CloudProvider?
    private(set) var linkError: String?

    @ObservationIgnored private let authorizer: OAuthAuthorizer
    @ObservationIgnored private let uploaders: [CloudProvider: any CloudUploading]
    @ObservationIgnored private let clientConfigs: any ClientConfigStoring
    @ObservationIgnored private let iCloud: ICloudDriveUploader
    @ObservationIgnored private let toast: ToastController
    @ObservationIgnored private let filenameTemplate: () -> FilenameTemplate
    @ObservationIgnored private let logger = Logger(subsystem: "com.bettershot.app", category: "destinations")
    @ObservationIgnored private var linkTask: Task<Void, Never>?

    /// Set by the composition root: opens Preferences on the Destinations tab, and keeps a failed upload restorable.
    @ObservationIgnored var showPreferences: () -> Void = {}
    @ObservationIgnored var recordClosed: (CGImage) -> Void = { _ in }

    init(
        authorizer: OAuthAuthorizer,
        uploaders: [CloudProvider: any CloudUploading],
        clientConfigs: any ClientConfigStoring,
        iCloud: ICloudDriveUploader = ICloudDriveUploader(),
        toast: ToastController,
        filenameTemplate: @escaping () -> FilenameTemplate
    ) {
        self.authorizer = authorizer
        self.uploaders = uploaders
        self.clientConfigs = clientConfigs
        self.iCloud = iCloud
        self.toast = toast
        self.filenameTemplate = filenameTemplate
        linkedProviders = Set(CloudProvider.allCases.filter { authorizer.isLinked($0) })
        configuredProviders = Set(CloudProvider.allCases.filter { authorizer.isConfigured($0) })
    }

    // MARK: Status for Preferences

    func isConfigured(_ provider: CloudProvider) -> Bool { configuredProviders.contains(provider) }

    // MARK: Client setup (the user's own app registration)

    /// The client the user entered for `provider`, if any (a bundled one isn't returned, and can't be edited).
    func savedConfig(for provider: CloudProvider) -> OAuthClientConfig? { clientConfigs.config(for: provider) }

    /// Stores the user's client. An account linked through a different client can't be renewed with the new one,
    /// so changing the client signs the account out and the user links it again.
    func saveConfig(_ config: OAuthClientConfig, for provider: CloudProvider) throws {
        let changed = clientConfigs.config(for: provider) != config
        try clientConfigs.save(config, for: provider)
        refreshConfigured()
        if changed { unlink(provider) }
    }

    func removeConfig(for provider: CloudProvider) {
        clientConfigs.removeConfig(for: provider)
        refreshConfigured()
        unlink(provider)
    }

    private func refreshConfigured() {
        configuredProviders = Set(CloudProvider.allCases.filter { authorizer.isConfigured($0) })
    }
    var isICloudAvailable: Bool { iCloud.isAvailable }

    func isInstalled(_ app: MessagingApp) -> Bool {
        app.bundleIdentifiers.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    // MARK: Linking

    func link(_ provider: CloudProvider) {
        guard linkTask == nil else { return }
        linkingProvider = provider
        linkError = nil
        linkTask = Task {
            do {
                try await authorizer.link(provider, openBrowser: { url in
                    await MainActor.run { _ = NSWorkspace.shared.open(url) }
                })
            } catch is CancellationError {
                // The user pressed Cancel.
            } catch {
                logger.error("Linking \(provider.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                linkError = error.localizedDescription
            }
            linkTask = nil
            linkingProvider = nil
            refreshLinked()
        }
    }

    func cancelLinking() {
        linkTask?.cancel()
    }

    func unlink(_ provider: CloudProvider) {
        Task {
            await authorizer.unlink(provider)
            refreshLinked()
        }
    }

    private func refreshLinked() {
        linkedProviders = Set(CloudProvider.allCases.filter { authorizer.isLinked($0) })
    }

    // MARK: Sending

    /// Sends `image` to `target`. Returns false, after telling the user why, when it can't be sent right now, so
    /// the preview stays open. Uploads run in the background and report with a toast; a failed one is kept for
    /// "Restore Recently Closed File".
    func send(_ image: CGImage, to target: StorageTarget) -> Bool {
        if let app = target.messagingApp {
            hand(image, to: app)
            return true
        }
        if target == .iCloud {
            guard iCloud.isAvailable else {
                present(ICloudDriveError.unavailable.localizedDescription, title: "iCloud Drive isn't available", offersPreferences: false)
                return false
            }
            upload(image, with: iCloud, label: "iCloud Drive")
            return true
        }
        guard let provider = target.cloudProvider, let uploader = uploaders[provider] else { return false }
        guard authorizer.isConfigured(provider) else {
            present(OAuthError.notConfigured(provider).localizedDescription, title: "\(provider.displayName) isn't set up", offersPreferences: false)
            return false
        }
        guard authorizer.isLinked(provider) else {
            present("Link your account in Preferences → Destinations first.", title: "\(provider.displayName) isn't linked", offersPreferences: true)
            return false
        }
        upload(image, with: uploader, label: provider.displayName)
        return true
    }

    /// The image goes onto the clipboard alone (no caption), then the desktop app or the web client opens to paste into.
    private func hand(_ image: CGImage, to app: MessagingApp) {
        ImageClipboard.copy(image)
        switch MessagingHandoff.plan(for: app, isInstalled: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }) {
        case .openApp(let bundleIdentifier):
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            toast.show("Image copied — paste it into \(app.displayName)", symbol: "doc.on.clipboard", duration: 4)
        case .openWeb(let url):
            NSWorkspace.shared.open(url)
            toast.show("Image copied — paste it into \(app.displayName) Web", symbol: "doc.on.clipboard", duration: 4)
        }
    }

    private func upload(_ image: CGImage, with uploader: any CloudUploading, label: String) {
        let data: Data
        do {
            data = try ImageExporter.data(for: image, format: .png)
        } catch {
            CaptureAlerts.present(error)
            return
        }
        let filename = filenameTemplate().filename(for: Date(), fileExtension: "png")
        toast.show("Uploading to \(label)…", symbol: "icloud.and.arrow.up", duration: 60)

        Task {
            do {
                let result = try await uploader.upload(data, filename: filename, mimeType: "image/png")
                if result.location.isFileURL && !result.isShareableLink {
                    toast.show("Saved to \(label)", symbol: "checkmark.icloud")
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.location.absoluteString, forType: .string)
                    toast.show(
                        result.isShareableLink ? "Link copied — \(label)" : "Uploaded to \(label) — link copied (only you can open it)",
                        symbol: "link"
                    )
                }
            } catch {
                logger.error("Upload to \(label, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                toast.dismiss()
                recordClosed(image)
                present("\(error.localizedDescription)\n\nYour capture was kept: use Restore Recently Closed File to bring it back.", title: "Upload to \(label) failed", offersPreferences: false)
            }
        }
    }

    private func present(_ message: String, title: String, offersPreferences: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: offersPreferences ? "Open Preferences" : "OK")
        if offersPreferences { alert.addButton(withTitle: "Cancel") }
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, offersPreferences { showPreferences() }
    }
}
