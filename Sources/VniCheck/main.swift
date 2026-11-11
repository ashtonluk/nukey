import Foundation
import VniCore

var failures = 0

func check(_ keys: String, _ expected: String, file: String = #file, line: Int = #line) {
    let e = VniEngine()
    var out = ""
    for k in keys { out = e.feed(k) }
    if out != expected {
        failures += 1
        print("FAIL \(keys): got \"\(out)\" expected \"\(expected)\"")
    }
}

// Dấu thanh
check("a1", "á"); check("a2", "à"); check("a3", "ả"); check("a4", "ã"); check("a5", "ạ")
check("a50", "a")
// Dấu phụ
check("a6", "â"); check("e6", "ê"); check("o6", "ô"); check("o7", "ơ"); check("u7", "ư")
check("a8", "ă"); check("d9", "đ")
// Từ
check("viet65", "việt"); check("chao2", "chào"); check("duong7", "dương")
check("nguoi72", "người"); check("hie65n", "hiện"); check("hien1", "hién"); check("tuy1", "túy")
check("quan1", "quán"); check("gia1", "giá")
check("co1", "có")
// Số giữ nguyên
check("2024", "2024"); check("a11", "a1")
// Hoa
check("A1", "Á"); check("D9", "Đ")

func checkTelex(_ keys: String, _ expected: String) {
    let engine = VniEngine()
    engine.inputMethod = .telex
    for key in keys { engine.feed(key) }
    if engine.current != expected {
        failures += 1
        print("FAIL Telex \(keys): got \"\(engine.current)\" expected \"\(expected)\"")
    }
}
checkTelex("cos", "có"); checkTelex("chaoF", "chào")
checkTelex("tieengs", "tiếng"); checkTelex("ddawng", "đăng")
checkTelex("nguowif", "người"); checkTelex("Vieetj", "Việt")
checkTelex("aaf", "ầ"); checkTelex("aw", "ă"); checkTelex("ow", "ơ")
checkTelex("uw", "ư"); checkTelex("ass", "as"); checkTelex("aww", "aw")
checkTelex("aa", "â"); checkTelex("aaz", "a"); checkTelex("2024", "2024")

let changeMethod = VniEngine()
changeMethod.feed("a")
changeMethod.inputMethod = .telex
assert(changeMethod.current.isEmpty)
changeMethod.feed("a"); changeMethod.feed("s")
assert(changeMethod.current == "á")

// Tổ hợp modifier chỉ kích hoạt một lần khi nhả, không chiếm phím tắt có chữ.
func checkShortcut(_ shortcut: ToggleShortcut, _ states: [ModifierKeys], expected: Int,
                   cancelAt: Int? = nil) {
    var detector = ModifierShortcutDetector()
    var count = 0
    for (index, state) in states.enumerated() {
        if index == cancelAt { detector.cancel() }
        if detector.update(state, shortcut: shortcut) { count += 1 }
    }
    if count != expected {
        failures += 1
        print("FAIL shortcut \(shortcut): got \(count), expected \(expected)")
    }
}
checkShortcut(.controlShift, [.control, [.control, .shift], .control, []], expected: 1)
checkShortcut(.commandShift, [.shift, [.command, .shift], .shift, []], expected: 1)
checkShortcut(.optionShift, [.option, [.option, .shift], .option, []], expected: 1)
checkShortcut(.controlShift, [.control, [.control, .shift], .control, []], expected: 0, cancelAt: 2)
checkShortcut(.controlShift, [.control, [.control, .shift], [.control, .shift, .command], .control, []], expected: 0)
checkShortcut(.none, [.control, [.control, .shift], .control, []], expected: 0)

// Tách từ và xóa
let e = VniEngine()
e.feed("a"); e.feed("1")
assert(e.current == "á")
assert(e.feed(" ") == "")
assert(e.feed("b") == "b")
let b = VniEngine()
for k in "viet65" { b.feed(k) }
b.backspace()
assert(b.current == "việ")

// Chỉ thay phần từ thay đổi, tránh xóa và gõ lại các ký tự đầu.
func checkEdit(_ old: String, _ new: String, deleting: Int, inserting: String) {
    let edit = TextEdit(from: old, to: new)
    if edit.deleteCount != deleting || edit.insertion != inserting ||
        String(old.dropLast(edit.deleteCount)) + edit.insertion != new {
        failures += 1
        print("FAIL edit \(old) → \(new): delete \(edit.deleteCount), insert \(edit.insertion)")
    }
}
checkEdit("co", "có", deleting: 1, inserting: "ó")
checkEdit("viet", "viêt", deleting: 2, inserting: "êt")
checkEdit("viêt", "việt", deleting: 2, inserting: "ệt")
checkEdit("có", "có", deleting: 0, inserting: "")
checkEdit("có", "có1", deleting: 0, inserting: "1")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
if failures != 0 { exit(1) }
