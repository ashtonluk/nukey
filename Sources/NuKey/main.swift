import Cocoa
import SwiftUI
import ServiceManagement
import VniCore

/// Ghi log chẩn đoán vào ~/Library/Logs/NuKey.log (không ghi nội dung gõ).
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/NuKey.log")

    static func write(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        }
    }
}

/// Tùy chọn lưu trong UserDefaults.
enum Pref {
    static let vni = "vniEnabled"
    static let loginSetupAttempted = "loginSetupAttempted"
    static let inputMethod = "inputMethod"
    static let shortcut = "toggleShortcut"
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store: ReplacementStore
    private let tap: InputTap
    private var rules: RulesWindowController!
    private var statusItem: NSStatusItem!
    private var permissionItem: NSMenuItem!
    private var loginModel: LoginModel!
    private var modeModel: ModeModel!
    private var methodItem: NSMenuItem!
    private var shortcutItem: NSMenuItem!

    private var selectedMethod: InputMethod {
        InputMethod(rawValue: UserDefaults.standard.string(forKey: Pref.inputMethod) ?? "") ?? .vni
    }

    private var selectedShortcut: ToggleShortcut {
        ToggleShortcut(rawValue: UserDefaults.standard.string(forKey: Pref.shortcut) ?? "") ?? .controlShift
    }

    override init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NuKey", isDirectory: true)
        store = ReplacementStore(url: support.appendingPathComponent("replacements.json"))
        tap = InputTap(store: store)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Pref.vni: true, Pref.inputMethod: InputMethod.vni.rawValue,
                                                   Pref.shortcut: ToggleShortcut.controlShift.rawValue])

        rules = RulesWindowController(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Bật một lần theo mặc định; về sau tôn trọng lựa chọn của người dùng.
        if Bundle.main.bundleURL.pathExtension == "app",
           !UserDefaults.standard.bool(forKey: Pref.loginSetupAttempted) {
            UserDefaults.standard.set(true, forKey: Pref.loginSetupAttempted)
            if SMAppService.mainApp.status == .notRegistered {
                setLaunchAtLogin(true)
            }
        }

        tap.vniEnabled = { UserDefaults.standard.bool(forKey: Pref.vni) }
        tap.inputMethod = { [weak self] in self?.selectedMethod ?? .vni }
        tap.shortcut = { [weak self] in self?.selectedShortcut ?? .controlShift }
        tap.toggleRequested = { [weak self] in
            guard let self else { return }
            self.setVietnameseEnabled(!UserDefaults.standard.bool(forKey: Pref.vni))
        }
        // Đang gõ trong cửa sổ của NuKey thì không tự thay từ
        tap.autoReplaceAllowed = { [weak self] in !(self?.rules.isKey ?? false) }

        // Event tap kiểu chủ động (đọc + sửa phím) cần quyền Trợ năng. Xin ngay khi mở để NuKey xuất hiện trong danh sách.
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        Log.write("khoi dong: accessibility=\(trusted)")
        // Bắt phím cần quyền Giám sát đầu vào (Input Monitoring)
        startTapWhenPermitted()
    }

    /// Event tap chỉ tạo được khi đã cấp quyền. Thử lại mỗi 2 giây để khỏi phải mở lại app.
    private func startTapWhenPermitted() {
        if tap.start() {
            Log.write("event tap: OK")
            return
        }
        Log.write("event tap: chua duoc cap quyen Giam sat dau vao, thu lai sau 2 giay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.startTapWhenPermitted()
        }
    }

    // MARK: - Menu

    private func updateStatusIcon() {
        let enabled = UserDefaults.standard.bool(forKey: Pref.vni)
        let name = enabled ? "MenuIcon-VI-generated" : "MenuIcon-EN-generated"
        guard let button = statusItem.button else { return }
        guard let source = NSImage(named: name) else {
            button.image = nil
            button.title = enabled ? "VI" : "EN"
            return
        }

        // Hai ảnh có cùng bố cục; cắt khoảng trống để giữ chiều cao chữ đồng đều.
        let size = NSSize(width: 21, height: 18)
        let icon = NSImage(size: size, flipped: false) { _ in
            source.draw(in: NSRect(origin: .zero, size: size),
                        from: NSRect(x: 508, y: 287, width: 520, height: 450),
                        operation: .sourceOver, fraction: 1)
            return true
        }
        icon.isTemplate = true
        button.title = ""
        button.image = icon
    }

    /// Menu dùng mục chuẩn của macOS (không nhúng view tùy biến) để tự có giao diện Liquid Glass.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // ENG | VNI: segmented của SwiftUI nhúng vào menu
        let modeItem = NSMenuItem()
        modeModel = ModeModel(vni: UserDefaults.standard.bool(forKey: Pref.vni),
                              methodTitle: selectedMethod == .vni ? "VNI" : "TELEX")
        modeModel.onChange = { [weak self] vni in
            self?.setVietnameseEnabled(vni)
        }
        let host = NSHostingView(rootView: ModePickerView(model: modeModel))
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 56)
        modeItem.view = host
        menu.addItem(modeItem)

        methodItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let methodMenu = NSMenu()
        for method in InputMethod.allCases {
            let item = NSMenuItem(title: method == .vni ? "VNI" : "Simple Telex", action: #selector(selectInputMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = method.rawValue
            methodMenu.addItem(item)
        }
        methodItem.submenu = methodMenu
        menu.addItem(methodItem)

        let manage = NSMenuItem(title: "Từ thay thế…", action: #selector(showRules), keyEquivalent: "")
        manage.target = self
        menu.addItem(manage)

        shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let shortcutMenu = NSMenu()
        for shortcut in ToggleShortcut.allCases {
            let item = NSMenuItem(title: shortcutTitle(shortcut), action: #selector(selectShortcut(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = shortcut.rawValue
            shortcutMenu.addItem(item)
        }
        shortcutItem.submenu = shortcutMenu
        menu.addItem(shortcutItem)
        refreshInputSettings()

        let spacingItem = NSMenuItem()
        spacingItem.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 5))
        menu.addItem(spacingItem)

        // Trợ năng: chỉ hiện khi chưa cấp quyền, nằm ngay trên "Khởi động cùng macOS"
        permissionItem = NSMenuItem(title: "Trợ năng: CHƯA cấp", action: #selector(openPrivacySettings), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(permissionItem)

        // Công tắc khởi động cùng máy Mac.
        loginModel = LoginModel()
        loginModel.onToggle = { [weak self] in self?.toggleLaunchAtLogin() }
        let loginItem = NSMenuItem()
        let loginHost = NSHostingView(rootView: LoginToggleView(model: loginModel))
        loginHost.frame = NSRect(x: 0, y: 0, width: 240, height: 28)
        loginItem.view = loginHost
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Thoát NuKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp   // để NSApplication xử lý, không gán cho AppDelegate (sẽ bị xám)
        menu.addItem(quit)
        return menu
    }

    /// Cập nhật trạng thái mỗi lần mở menu.
    func menuWillOpen(_ menu: NSMenu) {
        modeModel.vni = UserDefaults.standard.bool(forKey: Pref.vni)
        refreshInputSettings()
        refreshLoginItem()
        refreshPermissionItem()
    }

    private func shortcutTitle(_ shortcut: ToggleShortcut) -> String {
        switch shortcut {
        case .controlShift: return "⌃ ⇧"
        case .commandShift: return "⇧ ⌘"
        case .optionShift: return "⌥ ⇧"
        case .none: return "Tắt phím tắt"
        }
    }

    private func refreshInputSettings() {
        let method = selectedMethod
        let shortcut = selectedShortcut
        modeModel.methodTitle = method == .vni ? "VNI" : "TELEX"
        methodItem.title = "Kiểu gõ: \(method == .vni ? "VNI" : "Simple Telex")"
        shortcutItem.title = "Phím tắt: \(shortcutTitle(shortcut))"
        for item in methodItem.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == method.rawValue ? .on : .off
        }
        for item in shortcutItem.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == shortcut.rawValue ? .on : .off
        }
    }

    private func setVietnameseEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Pref.vni)
        tap.resetInput()
        modeModel.vni = enabled
        updateStatusIcon()
    }

    @objc private func selectInputMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let method = InputMethod(rawValue: raw) else { return }
        UserDefaults.standard.set(method.rawValue, forKey: Pref.inputMethod)
        tap.resetInput()
        refreshInputSettings()
    }

    @objc private func selectShortcut(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let shortcut = ToggleShortcut(rawValue: raw) else { return }
        UserDefaults.standard.set(shortcut.rawValue, forKey: Pref.shortcut)
        tap.resetShortcut()
        refreshInputSettings()
    }

    private func refreshLoginItem() {
        let status = SMAppService.mainApp.status
        loginModel.isOn = status == .enabled
        loginModel.title = status == .requiresApproval
            ? "Khởi động cùng máy Mac — cần cho phép…"
            : "Khởi động cùng máy Mac"
    }


    @objc private func toggleLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            refreshLoginItem()
        } else {
            setLaunchAtLogin(status != .enabled)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.write("khoi dong cung macOS: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Không thể cập nhật khởi động cùng macOS"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refreshLoginItem()
        refreshPermissionItem()
    }

    /// Đã cấp quyền thì ẩn mục này; chưa cấp thì hiện để bấm mở cài đặt.
    private func refreshPermissionItem() {
        permissionItem.isHidden = AXIsProcessTrusted()
    }

    /// Mở thẳng mục Giám sát đầu vào trong Cài đặt hệ thống và yêu cầu quyền.
    @objc private func openPrivacySettings() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func showRules() {
        rules.show()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // không hiện icon Dock
app.run()
