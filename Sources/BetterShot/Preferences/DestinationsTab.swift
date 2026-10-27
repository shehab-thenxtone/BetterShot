import BetterShotCore
import SwiftUI

struct DestinationsTab: View {
    let model: SettingsModel
    let center: DestinationsCenter

    @State private var setup: SetupTarget?

    private struct SetupTarget: Identifiable {
        let provider: CloudProvider
        var id: String { provider.rawValue }
    }

    var body: some View {
        Form {
            Section {
                Picker("Cloud button sends to", selection: Binding(
                    get: { model.settings.defaultStorageTarget },
                    set: { target in model.update { $0.updating(defaultStorageTarget: target) } }
                )) {
                    ForEach(StorageTarget.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Text("What the cloud button in the preview and result bar does. File hosts copy a link; WhatsApp and Telegram copy the image and open the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Cloud storage") {
                ForEach(CloudProvider.allCases, id: \.self) { providerRow($0) }
                Text("Images are copied into a BetterShot folder inside the Google Drive or OneDrive folder on your Mac, and that app uploads them, so no sign-in is needed. Signing in is optional: it lets BetterShot upload directly and copy a share link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = center.linkError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                iCloudRow
            }

            Section("Messaging") {
                ForEach(MessagingApp.allCases, id: \.self) { messagingRow($0) }
            }
        }
        .formStyle(.grouped)
        .onAppear { center.refreshFolders() }
        .sheet(item: $setup) { ClientSetupSheet(provider: $0.provider, center: center) }
    }

    // MARK: Rows

    @ViewBuilder
    private func providerRow(_ provider: CloudProvider) -> some View {
        folderRow(provider)
        accountRow(provider)
    }

    /// Where images go: the folder the desktop app syncs. No sign-in, client ID or secret involved.
    private func folderRow(_ provider: CloudProvider) -> some View {
        LabeledContent(provider.displayName) {
            HStack {
                if let folder = center.folder(for: provider) {
                    Text((folder.path as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .help(folder.path)
                } else {
                    Text("\(SyncedFolder.syncApp(for: provider).name) folder not found")
                        .foregroundStyle(.secondary)
                }
                Button("Choose…") { center.chooseFolder(for: provider) }
                    .help("Pick the folder that the \(SyncedFolder.syncApp(for: provider).name) app syncs")
                if center.isFolderChosen(for: provider) {
                    Button("Auto") { center.useDetectedFolder(for: provider) }
                        .help("Go back to the folder BetterShot found by itself")
                }
            }
        }
    }

    /// Optional: signing in lets BetterShot upload through the account and copy a share link.
    private func accountRow(_ provider: CloudProvider) -> some View {
        let isLinked = center.linkedProviders.contains(provider)
        let isLinking = center.linkingProvider == provider

        return LabeledContent("\(provider.displayName) sign-in") {
            HStack {
                Text(status(isLinked: isLinked, isLinking: isLinking))
                    .foregroundStyle(.secondary)
                if isLinking {
                    Button("Cancel") { center.cancelLinking() }
                } else if isLinked {
                    Button("Sign Out") { center.unlink(provider) }
                } else if center.isConfigured(provider) {
                    Button("Sign In…") { center.link(provider) }
                        .disabled(center.linkingProvider != nil)
                } else {
                    Button("Set Up…") { setup = SetupTarget(provider: provider) }
                        .help("Sign-in needs an app registration of your own; the folder above works without it")
                }
                if !isLinking, center.savedConfig(for: provider) != nil {
                    Button("Credentials…") { setup = SetupTarget(provider: provider) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func status(isLinked: Bool, isLinking: Bool) -> String {
        if isLinking { return "Waiting for your browser…" }
        return isLinked ? "Signed in — copies a share link" : "Optional — adds share links"
    }

    private var iCloudRow: some View {
        LabeledContent("iCloud Drive") {
            Text(center.isICloudAvailable ? "Saves to the BetterShot folder" : "Turn on iCloud Drive in System Settings")
                .foregroundStyle(.secondary)
        }
    }

    private func messagingRow(_ app: MessagingApp) -> some View {
        LabeledContent(app.displayName) {
            Text(center.isInstalled(app) ? "Desktop app found" : "App not installed — uses the web version")
                .foregroundStyle(.secondary)
        }
    }
}

extension StorageTarget {
    var label: String {
        switch self {
        case .local: "Local Storage"
        case .googleDrive: "Google Drive"
        case .oneDrive: "OneDrive"
        case .iCloud: "iCloud Drive"
        case .whatsApp: "WhatsApp"
        case .telegram: "Telegram"
        }
    }
}
