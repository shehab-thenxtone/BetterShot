import AppKit
import BetterShotCore
import SwiftUI

struct GeneralTab: View {
    let model: SettingsModel
    let folderStore: any SaveFolderStoring

    @State private var saveFolder: URL

    init(model: SettingsModel, folderStore: any SaveFolderStoring) {
        self.model = model
        self.folderStore = folderStore
        _saveFolder = State(initialValue: folderStore.folder)
    }

    var body: some View {
        Form {
            Section("Saving") {
                LabeledContent("Save location") {
                    HStack {
                        Text((saveFolder.path as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose…", action: chooseFolder)
                    }
                }
                TextField("Filename", text: binding(\.filenameTemplate.rawValue) { $0.updating(filenameTemplate: FilenameTemplate(rawValue: $1)) })
                Text("Example: \(exampleFilename). Use {date} and {time}.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Capture") {
                Picker("Self-timer delay", selection: binding(\.selfTimerDelay) { $0.updating(selfTimerDelay: $1) }) {
                    ForEach(SelfTimerDelay.allCases, id: \.self) { Text("\($0.seconds) seconds").tag($0) }
                }
                Toggle("Keep desktop icons hidden after capture",
                       isOn: binding(\.keepsDesktopIconsHidden) { $0.updating(keepsDesktopIconsHidden: $1) })
                Text("Off: Hide Desktop Icons is temporary and the icons return after your next capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Recording") {
                GIFSettingsView(
                    mode: binding(\.gifExportMode) { $0.updating(gifExportMode: $1) },
                    sourceFramesPerSecond: nil,
                    recordingDuration: nil
                )
                Text("How recordings are turned into GIFs. The Export GIF window shows a live size estimate for a real recording.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("After capture") {
                LabeledContent("Hide preview after") {
                    HStack {
                        Slider(value: binding(\.popupAutoDismissSeconds) { $0.updating(popupAutoDismissSeconds: $1) },
                               in: AppSettings.popupAutoDismissRange, step: 1)
                        Text("\(Int(model.settings.popupAutoDismissSeconds)) s")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Toggle("Open editor automatically after capture",
                       isOn: binding(\.opensEditorAfterCapture) { $0.updating(opensEditorAfterCapture: $1) })
            }

            Section("System") {
                Toggle("Launch at login", isOn: binding(\.launchesAtLogin) { $0.updating(launchesAtLogin: $1) })
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Helpers

    private var exampleFilename: String {
        model.settings.filenameTemplate.filename(for: Date(), fileExtension: "png")
    }

    /// Two-way binding onto one `AppSettings` field; writes go through the model so they persist.
    private func binding<Value>(
        _ keyPath: KeyPath<AppSettings, Value>,
        _ write: @escaping (AppSettings, Value) -> AppSettings
    ) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in model.update { write($0, newValue) } }
        )
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = saveFolder
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderStore.setFolder(url)
        saveFolder = url
    }
}
