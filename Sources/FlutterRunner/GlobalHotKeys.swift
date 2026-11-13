import Carbon.HIToolbox
import Foundation

/// System-wide shortcuts, so hot reload works while the simulator or the
/// editor has focus. Carbon hot keys need no Accessibility permission.
///
/// ⌃⌥↩ Run · ⌃⌥R Hot Reload · ⌃⌥⇧R Hot Restart · ⌃⌥. Stop
final class GlobalHotKeys {
    enum Action: UInt32 {
        case run = 1, hotReload, hotRestart, stop
    }

    static let shared = GlobalHotKeys()

    var onAction: ((Action) -> Void)?
    private var references: [EventHotKeyRef] = []
    private var installed = false

    func install() {
        guard !installed else { return }
        installed = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyId = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyId
            )
            if let action = GlobalHotKeys.Action(rawValue: hotKeyId.id) {
                DispatchQueue.main.async { GlobalHotKeys.shared.onAction?(action) }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        let controlOption = UInt32(controlKey | optionKey)
        register(.run, keyCode: kVK_Return, modifiers: controlOption)
        register(.hotReload, keyCode: kVK_ANSI_R, modifiers: controlOption)
        register(.hotRestart, keyCode: kVK_ANSI_R, modifiers: controlOption | UInt32(shiftKey))
        register(.stop, keyCode: kVK_ANSI_Period, modifiers: controlOption)
    }

    private func register(_ action: Action, keyCode: Int, modifiers: UInt32) {
        var reference: EventHotKeyRef?
        let hotKeyId = EventHotKeyID(signature: OSType(0x464C_5452), id: action.rawValue) // "FLTR"
        let status = RegisterEventHotKey(
            UInt32(keyCode), modifiers, hotKeyId, GetApplicationEventTarget(), 0, &reference
        )
        if status == noErr, let reference { references.append(reference) }
    }
}
