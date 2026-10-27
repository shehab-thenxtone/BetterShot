import BetterShotCore
import BetterShotServices
import SwiftUI

struct ShortcutsTab: View {
    let model: SettingsModel

    @State private var notice: Notice?

    private struct Notice {
        enum Style { case error, warning, info }
        let text: String
        let style: Style

        var color: Color {
            switch style {
            case .error: .red
            case .warning: .orange
            case .info: .secondary
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(CaptureMode.allCases, id: \.self) { mode in
                row(for: mode)
            }

            if let notice {
                Text(notice.text)
                    .font(.callout)
                    .foregroundStyle(notice.color)
            }

            Text("macOS uses ⇧⌘3, ⇧⌘4 and ⇧⌘5 for its own screenshots. Turn those off in System Settings → Keyboard → Keyboard Shortcuts → Screenshots, or pick different shortcuts here. The wand suggests an easy shortcut that nothing else is using.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Suggest for Empty Shortcuts", action: suggestForEmpty)
                    .help("Give every mode without a shortcut an easy one that nothing else is using")
                Spacer()
                Button("Reset to Defaults") {
                    notice = nil
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
            if let shortcut, let conflict = SystemShortcuts.conflict(for: shortcut) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("\(shortcut.displayString) is also \(conflict.purpose). macOS may handle it before BetterShot.")
                    .accessibilityLabel("\(shortcut.displayString) is also used by macOS for \(conflict.purpose)")
            }
            ShortcutRecorder(
                shortcut: shortcut,
                title: mode.title,
                onRecord: { record($0, for: mode) },
                onReject: { notice = Notice(text: $0, style: .error) }
            )
            .frame(width: 130, height: 24)
            Button { suggest(for: mode) } label: {
                Image(systemName: "wand.and.stars")
            }
            .buttonStyle(.borderless)
            .help("Suggest a free shortcut (press again for another)")
            .accessibilityLabel("Suggest a free shortcut for \(mode.title)")
            Button {
                notice = nil
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

    // MARK: Recording

    private func record(_ shortcut: KeyShortcut, for mode: CaptureMode) {
        guard shortcut.isUsableAsGlobalHotkey else {
            notice = Notice(text: "Shortcuts must include ⌘, ⌥ or ⌃.", style: .error)
            return
        }
        if let other = model.settings.hotkeys.conflict(for: shortcut, excluding: mode) {
            notice = Notice(text: "\(shortcut.displayString) is already used by “\(other.title)”.", style: .error)
            return
        }
        model.update { $0.updating(hotkeys: $0.hotkeys.setting(shortcut, for: mode)) }

        if let conflict = SystemShortcuts.conflict(for: shortcut) {
            notice = Notice(
                text: "\(shortcut.displayString) is also \(conflict.purpose). It's set, but macOS may handle it before BetterShot. Turn it off in System Settings → Keyboard → Keyboard Shortcuts, or press the wand for a free one.",
                style: .warning
            )
        } else {
            notice = nil
        }
    }

    // MARK: Suggestions

    /// Free means: not another mode's, not reserved by macOS, and registrable right now (which catches another
    /// app's global shortcut too).
    private func isFree(_ shortcut: KeyShortcut, for mode: CaptureMode, in hotkeys: HotkeyBindings) -> Bool {
        hotkeys.conflict(for: shortcut, excluding: mode) == nil
            && SystemShortcuts.conflict(for: shortcut) == nil
            && GlobalHotkeyCenter.isAvailable(shortcut)
    }

    private func suggest(for mode: CaptureMode) {
        let hotkeys = model.settings.hotkeys
        guard let suggestion = ShortcutSuggester.suggestion(
            for: mode, excluding: hotkeys.shortcut(for: mode), isFree: { isFree($0, for: mode, in: hotkeys) }
        ) else {
            notice = Notice(text: "No free shortcut was found. Clear one you don't use and try again.", style: .error)
            return
        }
        model.update { $0.updating(hotkeys: $0.hotkeys.setting(suggestion, for: mode)) }
        notice = Notice(text: "Suggested \(suggestion.displayString) for \(mode.title). Press the wand again for another.", style: .info)
    }

    private func suggestForEmpty() {
        var hotkeys = model.settings.hotkeys
        var filled = 0
        for mode in CaptureMode.allCases where hotkeys.shortcut(for: mode) == nil {
            let current = hotkeys
            if let suggestion = ShortcutSuggester.suggestion(for: mode, isFree: { isFree($0, for: mode, in: current) }) {
                hotkeys = hotkeys.setting(suggestion, for: mode)
                filled += 1
            }
        }
        guard filled > 0 else {
            notice = Notice(text: "Every mode already has a shortcut.", style: .info)
            return
        }
        model.update { $0.updating(hotkeys: hotkeys) }
        notice = Notice(text: "Suggested shortcuts for \(filled) \(filled == 1 ? "mode" : "modes").", style: .info)
    }
}
