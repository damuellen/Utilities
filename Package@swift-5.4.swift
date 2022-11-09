// swift-tools-version:5.4
import PackageDescription

#if os(Linux)
let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  targets: [
    .target(name: "Libc"),
    .target(name: "CZLib"),
    .target(name: "Units", dependencies: ["Helpers"]),
    .target(name: "Web", dependencies: ["Helpers"]),
    .target(name: "XML"),
    .target(name: "Utilities", dependencies: ["Helpers", "Units"]),
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
    .target(name: "Units", dependencies: ["Helpers"]),
    .target(name: "Web", dependencies: ["Helpers"]),
    .target(name: "XML"),
    .target(name: "Utilities", dependencies: ["Helpers", "Units"]),
    .target(name: "Helpers", dependencies: ["Libc"])
  ]
)
#endif
