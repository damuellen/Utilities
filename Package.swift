// swift-tools-version:4.2
import PackageDescription

let package = Package(
  name: "Utilities",
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  targets: [
    .target(name: "Libc"), 
    .target(name: "CZLib"),
    .target(name: "Units", dependencies: ["Libc"]),
    .target(name: "Web", dependencies: ["Helpers"]),
    .target(name: "XML"),
    .target(name: "Utilities", dependencies: ["Helpers", "Units"]),
    .target(name: "Helpers", dependencies: ["Libc", "CZLib"], exclude: ["GnuplotInit.swift"])
  ]
)
