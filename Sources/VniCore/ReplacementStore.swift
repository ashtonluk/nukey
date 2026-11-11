import Foundation

/// Từ thay thế do người dùng tự thêm: từ gốc → danh sách từ thay thế.
/// Mục đầu tiên của danh sách là mục sẽ tự động thay khi gặp lại từ gốc.
public final class ReplacementStore {
    public private(set) var map: [String: [String]]
    public let url: URL

    public init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            map = decoded
        } else {
            map = [:]
        }
    }

    public func alternatives(for word: String) -> [String] {
        map[word.lowercased()] ?? []
    }

    /// Từ sẽ tự thay khi người dùng gõ xong từ `word` (gõ dấu cách/dấu câu).
    public func autoReplacement(for word: String) -> String? {
        map[word.lowercased()]?.first
    }

    /// Thêm cặp từ gốc → từ thay thế. Cặp vừa thêm được đưa lên đầu (ưu tiên).
    public func add(_ from: String, _ to: String) {
        let key = from.lowercased()
        var list = map[key] ?? []
        list.removeAll { $0 == to }
        list.insert(to, at: 0)
        map[key] = list
        save()
    }

    /// Nhập từ file TXT: mỗi dòng một cặp `từ gốc<TAB>từ thay thế` (cũng nhận `=` hoặc `->`).
    /// Trả về số cặp đã nhập.
    @discardableResult
    public func importText(_ text: String) -> Int {
        var count = 0
        for line in text.split(whereSeparator: \.isNewline) {
            let raw = String(line)
            let parts: [String]
            if raw.contains("\t") {
                parts = raw.components(separatedBy: "\t")
            } else if let r = raw.range(of: "->") {
                parts = [String(raw[..<r.lowerBound]), String(raw[r.upperBound...])]
            } else if let r = raw.range(of: "=") {
                parts = [String(raw[..<r.lowerBound]), String(raw[r.upperBound...])]
            } else {
                continue
            }
            guard parts.count >= 2 else { continue }
            let from = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let to = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !from.isEmpty, !to.isEmpty else { continue }

            let key = from.lowercased()
            var list = map[key] ?? []
            if !list.contains(to) {
                list.insert(to, at: 0)
                map[key] = list
                count += 1
            }
        }
        save()
        return count
    }

    /// Xuất toàn bộ cặp ra văn bản TXT, mỗi dòng `từ gốc<TAB>từ thay thế`.
    public func exportText() -> String {
        entries.map { "\($0.from)\t\($0.to)" }.joined(separator: "\n") + "\n"
    }

    /// Xóa một cặp từ gốc → từ thay thế.
    public func remove(_ from: String, _ to: String) {
        let key = from.lowercased()
        guard var list = map[key] else { return }
        list.removeAll { $0 == to }
        map[key] = list.isEmpty ? nil : list
        save()
    }

    /// Toàn bộ cặp đã lưu, sắp theo từ gốc để hiển thị.
    public var entries: [(from: String, to: String)] {
        map.keys.sorted().flatMap { key in (map[key] ?? []).map { (from: key, to: $0) } }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(map)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("NuKey: không lưu được từ thay thế: \(error)")
        }
    }
}
