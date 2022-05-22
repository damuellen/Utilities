// swift-tools-version:5.4
import PackageDescription

#if os(Linux)
let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  targets: [
    .target(name: "Libc"),
    .target(name: "CZLib"),
    .target(name: "Physics", dependencies: ["Helpers"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: [
      "Libc", "CZLib",])
  ]
)
#else
let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  targets: [
    .target(name: "Libc"),
    .target(name: "Physics", dependencies: ["Helpers"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: ["Libc"])
  ]
)
#endif
