// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "Utilities",
  platforms: [.macOS(.v10_15), .iOS(.v15)],
  products: [.library(name: "Utilities", targets: ["Utilities"])],
  dependencies: [
    .package(url: "https://github.com/damuellen/xlsxwriter.swift.git", .branch("main")),
    .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0")
  ],
  targets: [
    .target(name: "Libc"), 
    .target(name: "CZLib"), 
    .target(name: "CIAPWSIF97"),
    .target(name: "Physics", dependencies: ["Helpers", "CIAPWSIF97"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: ["Libc", 
      .byName(name: "CZLib", condition: .when(platforms: [.macOS, .linux])),
      .product(name: "Cminizip", package: "xlsxwriter.swift", condition: .when(platforms: [.windows])),
      .product(name: "Numerics", package: "swift-numerics")])
  ]
)

#if os(Windows)
package.targets.removeAll(where: { $0.name == "CZLib" })
package.products.first!.linkerSettings = [.linkedLibrary("zlibstatic.lib")]
#elseif os(iOS)
package.targets.removeAll(where: { $0.name == "CZLib" })
#endif
