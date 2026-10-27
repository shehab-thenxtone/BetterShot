import BetterShotCore
import SwiftUI

/// GIF export options (requirements §3.1a): Auto derives everything from the recording; Manual exposes frame rate
/// (30 fps ceiling), colour depth, dithering and resolution. Used by the Export window and by Preferences.
struct GIFSettingsView: View {
    @Binding var mode: GIFExportMode
    /// The recording's frame rate, for describing what Auto will do. Nil in Preferences, where there is no recording.
    let sourceFramesPerSecond: Int?
    /// Length of the recording, to suggest a smaller scale for long ones.
    let recordingDuration: Double?

    private enum Kind: Hashable { case auto, manual }

    private static let longRecordingSeconds: Double = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("GIF settings", selection: kind) {
                Text("Auto").tag(Kind.auto)
                Text("Manual").tag(Kind.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .auto:
                Text(autoDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .manual:
                manualControls
            }
        }
    }

    // MARK: Manual controls

    private var manualControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Frame rate")
                Picker("Frame rate", selection: manual(\.framesPerSecond) { GIFExportSettings(framesPerSecond: $1, colorDepth: $0.colorDepth, isDitheringEnabled: $0.isDitheringEnabled, scale: $0.scale) }) {
                    ForEach(GIFExportSettings.frameRatePresets, id: \.self) { Text("\($0) fps").tag($0) }
                }
                .labelsHidden()
            }
            GridRow {
                Text("Quality")
                Picker("Quality", selection: manual(\.colorDepth) { GIFExportSettings(framesPerSecond: $0.framesPerSecond, colorDepth: $1, isDitheringEnabled: $0.isDitheringEnabled, scale: $0.scale) }) {
                    ForEach(GIFExportSettings.ColorDepth.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
            }
            GridRow {
                Text("Dithering")
                Toggle("Dithering", isOn: manual(\.isDitheringEnabled) { GIFExportSettings(framesPerSecond: $0.framesPerSecond, colorDepth: $0.colorDepth, isDitheringEnabled: $1, scale: $0.scale) })
                    .labelsHidden()
            }
            GridRow {
                Text("Resolution")
                Picker("Resolution", selection: manual(\.scale) { GIFExportSettings(framesPerSecond: $0.framesPerSecond, colorDepth: $0.colorDepth, isDitheringEnabled: $0.isDitheringEnabled, scale: $1) }) {
                    ForEach(GIFExportSettings.Scale.allCases, id: \.self) { Text("\(Int($0.rawValue * 100))%").tag($0) }
                }
                .labelsHidden()
            }
            if let recordingDuration, recordingDuration > Self.longRecordingSeconds {
                GridRow {
                    Text("")
                    Text("Long recording: 50–75% keeps the file smaller.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Bindings

    private var autoDescription: String {
        let frameRate = sourceFramesPerSecond.map { "\(min($0, GIFExportSettings.maxFramesPerSecond)) fps" } ?? "the recording's frame rate (up to \(GIFExportSettings.maxFramesPerSecond) fps)"
        return "Matches the recording at \(frameRate), 128 colours, dithering on, full size."
    }

    private var kind: Binding<Kind> {
        Binding(
            get: { if case .manual = mode { .manual } else { .auto } },
            set: { newKind in
                switch (newKind, mode) {
                case (.auto, _): mode = .auto
                case (.manual, .manual): break
                case (.manual, .auto): mode = .manual(GIFExportSettings()) // start from the recommended defaults
                }
            }
        )
    }

    private var manualSettings: GIFExportSettings {
        if case .manual(let settings) = mode { settings } else { GIFExportSettings() }
    }

    /// A binding onto one manual field. `write` rebuilds the settings (they're immutable) with the new value.
    private func manual<Value>(
        _ keyPath: KeyPath<GIFExportSettings, Value>,
        _ write: @escaping (GIFExportSettings, Value) -> GIFExportSettings
    ) -> Binding<Value> {
        Binding(
            get: { manualSettings[keyPath: keyPath] },
            set: { mode = .manual(write(manualSettings, $0)) }
        )
    }
}

private extension GIFExportSettings.ColorDepth {
    var label: String {
        switch self {
        case .low: "Low (\(colorCount) colours)"
        case .medium: "Medium (\(colorCount) colours)"
        case .high: "High (\(colorCount) colours)"
        }
    }
}
