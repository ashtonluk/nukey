import Cocoa
import VniCore

/// Đánh dấu các phím do chính app gửi đi, để tap bỏ qua và không xử lý lặp.
let nuKeyMarker: Int64 = 0x4E4B

/// Bắt phím toàn hệ thống bằng CGEventTap, gõ VNI bằng cách xóa ký tự cũ rồi gõ lại ký tự mới.
final class InputTap {
    private let engine = VniEngine()
    private let store: ReplacementStore
    private var port: CFMachPort?
    private var shortcutDetector = ModifierShortcutDetector()

    var vniEnabled: () -> Bool = { true }
    var inputMethod: () -> InputMethod = { .vni }
    var shortcut: () -> ToggleShortcut = { .controlShift }
    var toggleRequested: () -> Void = {}
    /// Trả về false khi không muốn tự thay từ (ví dụ đang gõ trong cửa sổ của chính NuKey).
    var autoReplaceAllowed: () -> Bool = { true }

    init(store: ReplacementStore) {
        self.store = store
    }

    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<InputTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.port = port
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    // MARK: - Xử lý sự kiện

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == nuKeyMarker {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            if !modifiers(event.flags).isEmpty { shortcutDetector.cancel() }
            return handleKey(event)
        case .flagsChanged:
            if shortcutDetector.update(modifiers(event.flags), shortcut: shortcut()) {
                resetInput()
                toggleRequested()
            }
        case .leftMouseDown:
            if !modifiers(event.flags).isEmpty { shortcutDetector.cancel() }
            engine.reset()
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKey(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Phím điều hướng / xóa / Enter / Tab / Esc: kết thúc từ hiện tại
        switch code {
        case 51:                                  // Backspace
            engine.backspace()
            return pass
        case 123, 124, 125, 126:                  // mũi tên
            engine.reset()
            return pass
        case 36, 48, 53, 76, 117:                 // Return, Tab, Esc, Enter numpad, Forward delete
            engine.reset()
            return pass
        default:
            break
        }

        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            engine.reset()
            return pass
        }
        guard vniEnabled(), let ch = typedChar(event) else {
            engine.reset()
            return pass
        }

        engine.inputMethod = inputMethod()

        if ch.isASCII && (ch.isLetter || ch.isNumber) {
            let old = engine.current
            let new = engine.feed(ch)
            if new == old + String(ch) { return pass }   // không biến đổi: gõ bình thường
            let edit = TextEdit(from: old, to: new)
            inject(deleting: edit.deleteCount, then: edit.insertion)
            return nil
        }

        // Dấu cách / dấu câu: kết thúc từ, tự thay nếu từ này đã có quy tắc
        let word = engine.current
        engine.reset()
        if !word.isEmpty, autoReplaceAllowed(), let replacement = store.autoReplacement(for: word) {
            inject(deleting: word.count, then: replacement + String(ch))
            return nil
        }
        return pass
    }

    func resetInput() { engine.reset() }

    func resetShortcut() { shortcutDetector = ModifierShortcutDetector() }

    private func modifiers(_ flags: CGEventFlags) -> ModifierKeys {
        var keys: ModifierKeys = []
        if flags.contains(.maskShift) { keys.insert(.shift) }
        if flags.contains(.maskControl) { keys.insert(.control) }
        if flags.contains(.maskAlternate) { keys.insert(.option) }
        if flags.contains(.maskCommand) { keys.insert(.command) }
        if flags.contains(.maskSecondaryFn) { keys.insert(.function) }
        return keys
    }

    private func typedChar(_ event: CGEvent) -> Character? {
        var buffer = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length).first
    }

    // MARK: - Gửi phím

    private func inject(deleting count: Int, then text: String) {
        for _ in 0..<count { postKey(51) }
        postText(text)
    }

    private func postKey(_ code: CGKeyCode) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            e.setIntegerValueField(.eventSourceUserData, value: nuKeyMarker)
            e.post(tap: .cgSessionEventTap)
        }
    }

    private func postText(_ text: String) {
        guard !text.isEmpty else { return }
        let units = Array(text.utf16)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
            e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            e.setIntegerValueField(.eventSourceUserData, value: nuKeyMarker)
            e.post(tap: .cgSessionEventTap)
        }
    }
}
