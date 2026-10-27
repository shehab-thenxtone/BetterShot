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
                Text("Sign in to the storage you want BetterShot to use. Set Up… takes your own app registration once; Link… then signs you in through your browser.")
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
        .sheet(item: $setup) { ClientSetupSheet(provider: $0.provider, center: center) }
    }

    // MARK: Rows

    @ViewBuilder
    private func providerRow(_ provider: CloudProvider) -> some View {
        let isLinked = center.linkedProviders.contains(provider)
        let isLinking = center.linkingProvider == provider

        LabeledContent(provider.displayName) {
            HStack {
                Text(status(provider, isLinked: isLinked, isLinking: isLinking))
                    .foregroundStyle(.secondary)
                if isLinking {
                    Button("Cancel") { center.cancelLinking() }
                } else if isLinked {
                    Button("Unlink") { center.unlink(provider) }
                } else if center.isConfigured(provider) {
                    Button("Link…") { center.link(provider) }
                        .disabled(center.linkingProvider != nil)
                } else {
                    Button("Set Up…") { setup = SetupTarget(provider: provider) }
                }
                if !isLinking, center.savedConfig(for: provider) != nil {
                    Button("Credentials…") { setup = SetupTarget(provider: provider) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func status(_ provider: CloudProvider, isLinked: Bool, isLinking: Bool) -> String {
        if isLinking { return "Waiting for your browser…" }
        if isLinked { return "Linked" }
        return center.isConfigured(provider) ? "Not linked" : "Needs your app registration"
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
