// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Utilities",
  platforms: [.macOS(.v10_15), .iOS(.v14)],
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  targets: [
    .target(name: "Libc"), 
    .target(name: "CZLib"), 
    .target(name: "CIAPWSIF97"),
    .target(name: "Physics", dependencies: ["Helpers", "CIAPWSIF97"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: ["Libc", 
      .byName(name: "CZLib", condition: .when(platforms: [.linux]))])
  ]
)
