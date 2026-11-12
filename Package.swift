// swift-tools-version:5.9
import PackageDescription

var products: [Product] = [.library(name: "ThumbTypeCore", targets: ["ThumbTypeCore"])]
var targets: [Target] = [
    // OSに依存しない部分（同時打鍵エンジン・配列読み込み）。Linuxでもテストできます。
    .target(name: "ThumbTypeCore"),
    .testTarget(name: "ThumbTypeCoreTests", dependencies: ["ThumbTypeCore"]),
]

#if os(macOS)
products.append(.executable(name: "ThumbType", targets: ["ThumbType"]))
targets.append(.executableTarget(name: "ThumbType", dependencies: ["ThumbTypeCore"]))
#endif

let package = Package(
    name: "ThumbType",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
