import SwiftUI

/// Trạng thái công tắc khởi động cùng máy Mac trong menu.
final class LoginModel: ObservableObject {
    @Published var isOn = false
    @Published var title = "Khởi động cùng máy Mac"
    var onToggle: (() -> Void)?
}

/// Dòng chữ + công tắc kiểu iOS vẽ bằng SwiftUI, đặt trong menu.
struct LoginToggleView: View {
    @ObservedObject var model: LoginModel

    var body: some View {
        HStack(spacing: 8) {
            Text(model.title)
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    model.onToggle?()
                }
            } label: {
                switchTrack
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(width: 240, height: 28)
    }

    /// Công tắc vẽ tay: màu accent cố định nên không bị nhạt khi menu không active.
    private var switchTrack: some View {
        ZStack(alignment: model.isOn ? .trailing : .leading) {
            Capsule()
                .fill(model.isOn ? Color(nsColor: .controlAccentColor) : Color.primary.opacity(0.2))
                .frame(width: 34, height: 20)
            Circle()
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .frame(width: 16, height: 16)
                .padding(2)
        }
        .frame(width: 34, height: 20)
    }
}
