// swift-tools-version:4.2
import PackageDescription

let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  dependencies: [
    .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0")
  ],
  targets: [
    .target(name: "Libc"), 
    .target(name: "CZLib"), 
    .target(name: "CIAPWSIF97"),
    .target(name: "Physics", dependencies: ["Helpers", "CIAPWSIF97"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: ["Libc", "CZLib", "Numerics"]),
  ]
)
