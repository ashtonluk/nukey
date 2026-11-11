/// Thao tác tối thiểu để biến phần cuối của từ cũ thành từ mới.
public struct TextEdit {
    public let deleteCount: Int
    public let insertion: String

    public init(from old: String, to new: String) {
        let commonCount = zip(old, new).prefix { $0 == $1 }.count
        deleteCount = old.count - commonCount
        insertion = String(new.dropFirst(commonCount))
    }
}
