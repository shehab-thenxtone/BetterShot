import BetterShotCore
import SwiftUI

struct DestinationsTab: View {
    let model: SettingsModel
    let center: DestinationsCenter

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
                } else {
                    Button("Link…") { center.link(provider) }
                        .disabled(!center.isConfigured(provider) || center.linkingProvider != nil)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func status(_ provider: CloudProvider, isLinked: Bool, isLinking: Bool) -> String {
        if isLinking { return "Waiting for your browser…" }
        if isLinked { return "Linked" }
        return center.isConfigured(provider) ? "Not linked" : "Not set up in this build"
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
