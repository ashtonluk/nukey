// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NuKey",
    platforms: [.macOS(.v13)],
    targets: [
        // Lõi gõ VNI + từ thay thế. Không dùng AppKit nên chạy/test được trên dòng lệnh.
        .target(name: "VniCore"),
        // App menu bar: bắt phím (CGEventTap), popup khi bôi đen từ.
        .executableTarget(name: "NuKey", dependencies: ["VniCore"]),
        // Kiểm thử engine (không cần XCTest, chỉ cần Command Line Tools).
        .executableTarget(name: "VniCheck", dependencies: ["VniCore"]),
    ]
)
