import BetterShotCore
import Carbon.HIToolbox

/// System-wide hotkeys via Carbon `RegisterEventHotKey`, which needs no Accessibility permission
/// (requirements §4.3). Handlers run on the main actor.
@MainActor
public final class GlobalHotkeyCenter {
    public struct Binding {
        public let shortcut: KeyShortcut
        public let handler: @MainActor () -> Void

        public init(shortcut: KeyShortcut, handler: @escaping @MainActor () -> Void) {
            self.shortcut = shortcut
            self.handler = handler
        }
    }

    private static let signature: OSType = 0x4253_4854 // 'BSHT'

    private var registrations: [UInt32: (ref: EventHotKeyRef, handler: @MainActor () -> Void)] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    public init() {}

    /// Replaces every registered hotkey with `bindings`. Returns the shortcuts that couldn't be registered
    /// (unknown key, or already claimed by the system or another app).
    @discardableResult
    public func replaceAll(with bindings: [Binding]) -> [KeyShortcut] {
        unregisterAll()
        installEventHandlerIfNeeded()

        var failed: [KeyShortcut] = []
        for binding in bindings {
            guard let keyCode = KeyCodeMap.keyCode(for: binding.shortcut.key) else {
                failed.append(binding.shortcut)
                continue
            }
            let id = nextID
            nextID += 1

            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                keyCode,
                KeyCodeMap.carbonModifiers(for: binding.shortcut.modifiers),
                EventHotKeyID(signature: Self.signature, id: id),
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                registrations[id] = (ref, binding.handler)
            } else {
                failed.append(binding.shortcut)
            }
        }
        return failed
    }

    public func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
    }

    // MARK: Private

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard status == noErr else { return status }

                let center = Unmanaged<GlobalHotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { center.fire(hotKeyID.id) } // Carbon delivers on the main thread
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func fire(_ id: UInt32) {
        registrations[id]?.handler()
    }
}
