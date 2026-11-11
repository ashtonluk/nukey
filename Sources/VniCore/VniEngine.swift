import Foundation

/// Bộ gõ VNI tối giản.
/// Giữ danh sách ký tự của từ đang gõ (rất nhỏ, vài chục byte) và render ra tiếng Việt.
///
/// Quy tắc VNI:
///   6 → ^ (â, ê, ô)     7 → móc (ơ, ư)     8 → breve (ă)     9 → đ
///   1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng, 0 bỏ dấu thanh
public enum InputMethod: String, CaseIterable {
    case vni, telex
}

public final class VniEngine {
    enum Mark: Equatable { case none, circumflex, horn, breve, stroke }

    struct Glyph {
        var char: Character      // chữ thường gốc (hoặc ký tự nguyên gốc nếu không phải chữ)
        var upper: Bool
        var mark: Mark = .none
        var isLetter: Bool
    }

    private var glyphs: [Glyph] = []
    private var tone: Int = 0    // 0 = không dấu, 1...5
    /// Chuỗi đang hiển thị của từ hiện tại.
    public private(set) var current: String = ""
    public var inputMethod: InputMethod = .vni {
        didSet { if inputMethod != oldValue { reset() } }
    }

    public init() {}

    public func reset() {
        glyphs.removeAll(keepingCapacity: true)
        tone = 0
        current = ""
    }

    /// Xóa ký tự cuối (khi người dùng bấm Backspace).
    public func backspace() {
        if !glyphs.isEmpty { glyphs.removeLast() }
        if glyphs.isEmpty { tone = 0 }
        current = render()
    }

    /// Nạp một ký tự gõ vào. Trả về chuỗi hiển thị mới của từ.
    /// Ký tự không phải chữ/số kết thúc từ: trả về chuỗi rỗng.
    @discardableResult
    public func feed(_ c: Character) -> String {
        if c.isASCII && c.isLetter {
            if inputMethod == .telex { feedTelex(c) }
            else { appendLetter(c) }
        } else if c.isASCII, let d = c.wholeNumberValue {
            if inputMethod == .vni { feedDigit(d, c) }
            else { glyphs.append(literal(c)) }
        } else {
            reset()
            return current
        }
        current = render()
        return current
    }

    private func appendLetter(_ c: Character) {
        glyphs.append(Glyph(char: Character(c.lowercased()), upper: c.isUppercase, isLetter: true))
    }

    private func feedTelex(_ c: Character) {
        let key = Character(c.lowercased())
        let tones: [Character: Int] = ["s": 1, "f": 2, "r": 3, "x": 4, "j": 5]
        if let newTone = tones[key], !vowelIndices().isEmpty {
            if tone == newTone {
                tone = 0
                appendLetter(c)
            } else {
                tone = newTone
            }
            return
        }
        if key == "z", tone != 0 || glyphs.contains(where: { $0.mark != .none }) {
            tone = 0
            for i in glyphs.indices { glyphs[i].mark = .none }
            return
        }
        if ["a", "e", "o", "d"].contains(key), let i = glyphs.indices.last,
           glyphs[i].isLetter, glyphs[i].char == key {
            let mark: Mark = key == "d" ? .stroke : .circumflex
            if glyphs[i].mark == .none {
                glyphs[i].mark = mark
                return
            } else if glyphs[i].mark == mark {
                glyphs[i].mark = .none
                appendLetter(c)
                return
            }
        }
        if key == "w", let i = glyphs.lastIndex(where: {
            $0.isLetter && ["a", "o", "u"].contains($0.char)
        }) {
            let mark: Mark = glyphs[i].char == "a" ? .breve : .horn
            if glyphs[i].mark == .none {
                glyphs[i].mark = mark
                if glyphs[i].char == "o", i > 0, glyphs[i - 1].char == "u",
                   glyphs[i - 1].mark == .none { glyphs[i - 1].mark = .horn }
                return
            } else if glyphs[i].mark == mark {
                glyphs[i].mark = .none
                if glyphs[i].char == "o", i > 0, glyphs[i - 1].char == "u",
                   glyphs[i - 1].mark == .horn { glyphs[i - 1].mark = .none }
                appendLetter(c)
                return
            }
        }
        appendLetter(c)
    }

    // MARK: - Nhập số (dấu VNI)

    private func feedDigit(_ d: Int, _ c: Character) {
        // Số 0–5 chỉ là dấu thanh khi từ đã có nguyên âm; ngược lại giữ như chữ số thường
        if d <= 5 && vowelIndices().isEmpty {
            glyphs.append(literal(c))
            return
        }
        switch d {
        case 1...5:
            if tone == d {              // gõ lại đúng dấu thì bỏ dấu và giữ số như chữ thường
                tone = 0
                glyphs.append(literal(c))
            } else {
                tone = d
            }
        case 0:
            tone = 0
        case 6: applyMark(.circumflex, bases: ["a", "e", "o"], literal: c)
        case 7: applyMark(.horn, bases: ["o", "u"], literal: c)
        case 8: applyMark(.breve, bases: ["a"], literal: c)
        case 9: applyMark(.stroke, bases: ["d"], literal: c)
        default: break
        }
    }

    private func applyMark(_ mark: Mark, bases: Set<Character>, literal c: Character) {
        // Chữ gần nhất chưa có dấu phụ
        if let i = glyphs.lastIndex(where: { $0.isLetter && bases.contains($0.char) && $0.mark == .none }) {
            glyphs[i].mark = mark
            // "uo7" → "ươ": móc luôn chữ u đứng ngay trước ơ
            if mark == .horn, glyphs[i].char == "o", i > 0,
               glyphs[i - 1].char == "u", glyphs[i - 1].mark == .none {
                glyphs[i - 1].mark = .horn
            }
        } else if let i = glyphs.lastIndex(where: { $0.isLetter && bases.contains($0.char) && $0.mark == mark }) {
            glyphs[i].mark = .none       // gõ lại lần nữa: bỏ dấu, giữ số
            glyphs.append(literal(c))
        } else {
            glyphs.append(literal(c))    // không có chữ phù hợp: coi như số thường
        }
    }

    private func literal(_ c: Character) -> Glyph {
        Glyph(char: c, upper: false, isLetter: false)
    }

    // MARK: - Render

    private func render() -> String {
        if glyphs.isEmpty { return "" }
        let tonePos = tone > 0 ? tonePosition() : nil
        var out = ""
        for (i, g) in glyphs.enumerated() {
            out += compose(g, tone: i == tonePos ? tone : 0)
        }
        return out
    }

    private func compose(_ g: Glyph, tone: Int) -> String {
        guard g.isLetter else { return String(g.char) }
        if g.mark == .stroke { return g.upper ? "Đ" : "đ" }

        var s = String(g.char)
        switch g.mark {
        case .circumflex: s += "\u{0302}"
        case .horn: s += "\u{031B}"
        case .breve: s += "\u{0306}"
        default: break
        }
        let toneMarks = ["", "\u{0301}", "\u{0300}", "\u{0309}", "\u{0303}", "\u{0323}"]
        s += toneMarks[tone]
        if g.upper { s = s.uppercased() }
        return s.precomposedStringWithCanonicalMapping
    }

    /// Vị trí nguyên âm sẽ mang dấu thanh.
    private func tonePosition() -> Int? {
        let vowels = vowelIndices()
        if vowels.isEmpty { return nil }

        // 1. Nguyên âm có dấu phụ (ă â ê ô ơ ư) được ưu tiên
        if let i = vowels.last(where: { glyphs[$0].mark != .none }) { return i }

        // 2. Nhóm nguyên âm liên tiếp đầu tiên
        var groups: [[Int]] = []
        for i in vowels {
            if let last = groups.last?.last, last == i - 1 {
                groups[groups.count - 1].append(i)
            } else {
                groups.append([i])
            }
        }
        let g = groups[0]
        switch g.count {
        case 1:
            return g[0]
        case 2:
            if g[1] + 1 < glyphs.count, glyphs[g[1] + 1].isLetter { return g[1] }   // có phụ âm cuối
            return g[0]                                                             // "ai", "oa", "uy"...
        default:
            return g[g.count / 2]
        }
    }

    private func vowelIndices() -> [Int] {
        var res: [Int] = []
        for (i, g) in glyphs.enumerated() where g.isLetter {
            let b = g.char
            guard "aeiouy".contains(b) else { continue }
            if b == "u", i > 0, glyphs[i - 1].char == "q" { continue }                 // "qu" là phụ âm
            if b == "i", i > 0, glyphs[i - 1].char == "g",
               i + 1 < glyphs.count, "aeiouy".contains(glyphs[i + 1].char) { continue } // "gi" + nguyên âm
            res.append(i)
        }
        return res
    }
}
