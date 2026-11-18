// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CAT2RIG",
    platforms: [.macOS(.v13)],
    targets: [
        // logika: port szeregowy, CI-V, protokół i serwer rigctl
        .target(name: "CAT2RIGCore", path: "Sources/CAT2RIGCore"),
        // aplikacja SwiftUI
        .executableTarget(name: "CAT2RIG", dependencies: ["CAT2RIGCore"], path: "Sources/CAT2RIG"),
        // testy:  swift test
        .testTarget(name: "CAT2RIGCoreTests", dependencies: ["CAT2RIGCore"],
                    path: "Tests/CAT2RIGCoreTests"),
    ]
)
