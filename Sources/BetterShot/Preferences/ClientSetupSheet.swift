import BetterShotCore
import SwiftUI

/// Where a user without a bundled client ID registers their own and pastes it in, so they can sign in to the
/// cloud storage they want.
struct ClientSetupSheet: View {
    let provider: CloudProvider
    let center: DestinationsCenter

    @Environment(\.dismiss) private var dismiss
    @State private var clientID: String
    @State private var clientSecret: String
    @State private var errorMessage: String?

    init(provider: CloudProvider, center: DestinationsCenter) {
        self.provider = provider
        self.center = center
        let saved = center.savedConfig(for: provider)
        _clientID = State(initialValue: saved?.clientID ?? "")
        _clientSecret = State(initialValue: saved?.clientSecret ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up \(provider.displayName)").font(.headline)
            Text("BetterShot signs in with an app registration of your own, so your files and sign-in stay between you and \(provider.displayName). Create one once:")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(provider.setupSteps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").font(.callout)
                }
            }
            Link("Open \(provider.consoleName)", destination: provider.consoleURL)
                .font(.callout)

            TextField(provider.clientIDLabel, text: $clientID)
                .textFieldStyle(.roundedBorder)
            if provider.usesClientSecret {
                SecureField("Client secret", text: $clientSecret)
                    .textFieldStyle(.roundedBorder)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if center.savedConfig(for: provider) != nil {
                    Button("Remove", role: .destructive) {
                        center.removeConfig(for: provider)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func save() {
        let secret = clientSecret.trimmingCharacters(in: .whitespaces)
        let config = OAuthClientConfig(
            clientID: clientID.trimmingCharacters(in: .whitespaces),
            clientSecret: provider.usesClientSecret && !secret.isEmpty ? secret : nil
        )
        do {
            try center.saveConfig(config, for: provider)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension CloudProvider {
    var usesClientSecret: Bool { self == .googleDrive }

    var clientIDLabel: String { self == .googleDrive ? "Client ID" : "Application (client) ID" }

    var consoleName: String {
        switch self {
        case .googleDrive: "Google Cloud Console"
        case .oneDrive: "Microsoft Entra admin center"
        }
    }

    var consoleURL: URL {
        switch self {
        case .googleDrive: URL(string: "https://console.cloud.google.com/apis/credentials")!
        case .oneDrive: URL(string: "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!
        }
    }

    var setupSteps: [String] {
        switch self {
        case .googleDrive: [
            "Create a project and turn on the Google Drive API.",
            "Credentials → Create credentials → OAuth client ID.",
            "Application type: Desktop app.",
            "Copy the client ID and client secret below.",
        ]
        case .oneDrive: [
            "App registrations → New registration.",
            "Account types: personal Microsoft accounts and any organisation.",
            "Redirect URI: platform “Mobile and desktop applications”, value http://localhost.",
            "Authentication → Allow public client flows: Yes.",
            "API permissions → Microsoft Graph → Files.ReadWrite (delegated).",
            "Copy the Application (client) ID below.",
        ]
        }
    }
}
