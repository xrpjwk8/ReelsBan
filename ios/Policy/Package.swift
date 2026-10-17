// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "ReelsBanPolicy", products: [.library(name: "ReelsBanPolicy", targets: ["ReelsBanPolicy"])], targets: [.target(name: "ReelsBanPolicy"), .testTarget(name: "ReelsBanPolicyTests", dependencies: ["ReelsBanPolicy"])])
