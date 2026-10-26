import BetterShotCore
import SwiftUI

struct ShortcutsTab: View {
    let model: SettingsModel

    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(CaptureMode.allCases, id: \.self) { mode in
                row(for: mode)
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Text("macOS uses ⇧⌘3, ⇧⌘4 and ⇧⌘5 for its own screenshots. Turn those off in System Settings → Keyboard → Keyboard Shortcuts → Screenshots, or pick different shortcuts here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    message = nil
                    model.update { $0.updating(hotkeys: .defaults) }
                }
            }
        }
        .padding()
    }

    private func row(for mode: CaptureMode) -> some View {
        let shortcut = model.settings.hotkeys.shortcut(for: mode)
        return HStack {
            Text(mode.title)
            Spacer()
            ShortcutRecorder(
                shortcut: shortcut,
                title: mode.title,
                onRecord: { record($0, for: mode) },
                onReject: { message = $0 }
            )
            .frame(width: 130, height: 24)
            Button {
                message = nil
                model.update { $0.updating(hotkeys: $0.hotkeys.setting(nil, for: mode)) }
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(shortcut == nil)
            .help("Clear shortcut")
            .accessibilityLabel("Clear shortcut for \(mode.title)")
        }
    }

    private func record(_ shortcut: KeyShortcut, for mode: CaptureMode) {
        guard shortcut.isUsableAsGlobalHotkey else {
            message = "Shortcuts must include ⌘, ⌥ or ⌃."
            return
        }
        if let other = model.settings.hotkeys.conflict(for: shortcut, excluding: mode) {
            message = "\(shortcut.displayString) is already used by “\(other.title)”."
            return
        }
        message = nil
        model.update { $0.updating(hotkeys: $0.hotkeys.setting(shortcut, for: mode)) }
    }
}
