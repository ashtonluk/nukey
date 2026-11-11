import Cocoa
import UniformTypeIdentifiers
import VniCore

/// Bảng chỉ hiện menu chuột phải khi bấm đúng vào một dòng, không hiện ở khoảng trống.
final class RulesTable: NSTableView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        guard row >= 0 else { return nil }
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        return super.menu(for: event)
    }
}

/// Cửa sổ từ menu: nhập từ cần thay và từ thay bằng, xem danh sách, xóa mục đã chọn.
final class RulesWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let store: ReplacementStore
    private let window: NSWindow
    private let fromField = NSTextField()
    private let toField = NSTextField()
    private let table = RulesTable()
    private let deleteButton = NSButton()
    private let folderButton = NSButton()
    private var entries: [(from: String, to: String)] = []

    var isKey: Bool { window.isKeyWindow }

    init(store: ReplacementStore) {
        self.store = store
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "Từ thay thế"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        fromField.placeholderString = "Từ cần thay (ví dụ: hiện)"
        toField.placeholderString = "Thay bằng (ví dụ: hiển thị)"
        for field in [fromField, toField] {
            field.target = self
            field.action = #selector(addTapped)
        }

        let addButton = NSButton(title: "Thêm", target: self, action: #selector(addTapped))
        addButton.keyEquivalent = "\r"

        // Bảng danh sách: hai cột, chọn một dòng rồi bấm Xóa
        let fromColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("from"))
        fromColumn.title = "Từ cần thay"
        fromColumn.width = 160
        let toColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("to"))
        toColumn.title = "Thay bằng"
        toColumn.width = 170
        table.addTableColumn(fromColumn)
        table.addTableColumn(toColumn)
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true

        // Chuột phải vào dòng để xóa, giống menu chuột phải của macOS
        let contextMenu = NSMenu()
        let deleteItem = NSMenuItem(title: "Xóa", action: #selector(deleteTapped), keyEquivalent: "")
        deleteItem.target = self
        contextMenu.addItem(deleteItem)
        table.menu = contextMenu

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 220).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 340).isActive = true

        deleteButton.title = "Xóa mục đã chọn"
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.isEnabled = false

        folderButton.title = "Mở thư mục dữ liệu"
        folderButton.target = self
        folderButton.action = #selector(openFolderTapped)

        let importButton = NSButton(title: "Nhập TXT…", target: self, action: #selector(importTapped))
        let exportButton = NSButton(title: "Xuất TXT…", target: self, action: #selector(exportTapped))

        let buttons = NSStackView(views: [deleteButton, folderButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8

        let fileButtons = NSStackView(views: [importButton, exportButton])
        fileButtons.orientation = .horizontal
        fileButtons.spacing = 8

        let main = NSStackView(views: [
            label("Từ cần thay"), fromField,
            label("Thay bằng"), toField,
            addButton,
            separator(),
            label("Đã lưu"), scroll,
            buttons,
            fileButtons,
        ])
        main.orientation = .vertical
        main.alignment = .leading
        main.spacing = 8
        main.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        main.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            fromField.widthAnchor.constraint(equalToConstant: 340),
            toField.widthAnchor.constraint(equalToConstant: 340),
        ])
        window.contentView = content
    }

    func show() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Helpers giao diện

    /// Đường kẻ ngang (NSBox mặc định hiện chữ "Title" nên không dùng).
    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 340).isActive = true
        return box
    }

    private func label(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 12, weight: .medium)
        return l
    }

    // MARK: - Dữ liệu

    private func reload() {
        entries = store.entries
        table.reloadData()
        deleteButton.isEnabled = table.selectedRow >= 0
    }

    @objc private func addTapped() {
        let from = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = toField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return }
        store.add(from, to)
        fromField.stringValue = ""
        toField.stringValue = ""
        reload()
        window.makeFirstResponder(fromField)
    }

    @objc private func exportTapped() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tu-thay-the.txt"
        panel.allowedContentTypes = [.plainText]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.store.exportText().write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.showAlert("Không xuất được file", error.localizedDescription)
            }
        }
    }

    @objc private func importTapped() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let count = self.store.importText(text)
                self.reload()
                self.showAlert("Đã nhập \(count) từ", "Các từ trùng với danh sách hiện tại được bỏ qua.")
            } catch {
                self.showAlert("Không nhập được file", error.localizedDescription)
            }
        }
    }

    private func showAlert(_ title: String, _ info: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.beginSheetModal(for: window)
    }

    @objc private func openFolderTapped() {
        let dir = store.url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func deleteTapped() {
        // Ưu tiên dòng vừa chuột phải; không có thì xóa dòng đang chọn
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard row >= 0, row < entries.count else { return }
        let entry = entries[row]
        store.remove(entry.from, entry.to)
        reload()
    }

    // MARK: - NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < entries.count else { return nil }
        return tableColumn?.identifier.rawValue == "from" ? entries[row].from : entries[row].to
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        deleteButton.isEnabled = table.selectedRow >= 0
    }
}
