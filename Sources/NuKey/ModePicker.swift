import SwiftUI

/// Trạng thái chế độ gõ, nối với menu và với UserDefaults qua AppDelegate.
final class ModeModel: ObservableObject {
    @Published var vni: Bool
    @Published var methodTitle: String
    var onChange: ((Bool) -> Void)?

    init(vni: Bool, methodTitle: String) {
        self.vni = vni
        self.methodTitle = methodTitle
    }
}

/// Segmented ENG | VNI vẽ bằng SwiftUI.
/// Ô đang chọn dùng màu accent cố định của hệ thống nên không bị xám khi menu không active.
struct ModePickerView: View {
    @ObservedObject var model: ModeModel
    /// Dùng chung để ô màu accent trượt từ segment này sang segment kia.
    @Namespace private var knob

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                segment("ENG", selected: !model.vni) { select(vni: false) }
                segment(model.methodTitle, selected: model.vni) { select(vni: true) }
            }
            .padding(3)
            .frame(width: 208, height: 32)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .padding(.top, 10)
            .frame(height: 46, alignment: .top)

            // Đường kẻ ngăn với mục "Từ thay thế…" bên dưới
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 12)
                .frame(height: 10)
        }
        .frame(width: 240, height: 56)
    }

    private func select(vni: Bool) {
        guard vni != model.vni else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            model.vni = vni
        }
        model.onChange?(vni)
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color(nsColor: .controlAccentColor))
                            .matchedGeometryEffect(id: "knob", in: knob)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
