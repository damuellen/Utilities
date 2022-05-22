// swift-tools-version:5.4
import PackageDescription

let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  // dependencies: [.package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0")],
  targets: [
    .target(name: "Libc"),
    .target(name: "CZLib"),
    .target(name: "Physics", dependencies: ["Helpers"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(
      name: "Helpers", dependencies: ["Libc", "CZLib",
    ])// .product(name: "Numerics", package: "swift-numerics")]),
  ]
)
