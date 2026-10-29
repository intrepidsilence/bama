// swift-tools-version: 6.2
import PackageDescription

// Rules and data logic with no SwiftUI, shared by every app target, so tests
// run without the app:
//   swift test --package-path __APP_NAME__Kit --scratch-path ~/Library/Developer/__APP_NAME__/kit-build
let package = Package(
    name: "__APP_NAME__Kit",
    platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26), .watchOS(.v26), .visionOS(.v26)],
    products: [.library(name: "__APP_NAME__Kit", targets: ["__APP_NAME__Kit"])],
    targets: [
        .target(name: "__APP_NAME__Kit"),
        .testTarget(name: "__APP_NAME__KitTests", dependencies: ["__APP_NAME__Kit"]),
    ]
)
