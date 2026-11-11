public struct ModifierKeys: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let shift = ModifierKeys(rawValue: 1 << 0)
    public static let control = ModifierKeys(rawValue: 1 << 1)
    public static let option = ModifierKeys(rawValue: 1 << 2)
    public static let command = ModifierKeys(rawValue: 1 << 3)
    public static let function = ModifierKeys(rawValue: 1 << 4)
}

public enum ToggleShortcut: String, CaseIterable {
    case controlShift, commandShift, optionShift, none

    public var modifiers: ModifierKeys {
        switch self {
        case .controlShift: return [.control, .shift]
        case .commandShift: return [.command, .shift]
        case .optionShift: return [.option, .shift]
        case .none: return []
        }
    }
}

/// Chỉ nhận tổ hợp khi nhả ra mà không có phím hay modifier khác xen vào.
public struct ModifierShortcutDetector {
    private enum State { case idle, armed, blocked }
    private var state: State = .idle

    public init() {}

    public mutating func cancel() { state = .blocked }

    public mutating func update(_ modifiers: ModifierKeys, shortcut: ToggleShortcut) -> Bool {
        if modifiers.isEmpty {
            let trigger = state == .armed && shortcut != .none
            state = .idle
            return trigger
        }
        guard shortcut != .none else { state = .blocked; return false }
        switch state {
        case .idle:
            if modifiers == shortcut.modifiers { state = .armed }
            else if !shortcut.modifiers.isSuperset(of: modifiers) { state = .blocked }
        case .armed:
            if modifiers != shortcut.modifiers {
                if shortcut.modifiers.isSuperset(of: modifiers) {
                    state = .blocked
                    return true
                }
                state = .blocked
            }
        case .blocked:
            break
        }
        return false
    }
}
