// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Utilities",
  platforms: [.macOS(.v10_15), .iOS(.v14)],
  products: [.library(name: "Utilities", targets: ["Utilities"])],
    dependencies: [
     .package(url: "https://github.com/pvieito/PythonKit.git", .branch("master"))
   ],
  targets: [
    .target(name: "Libc"), 
    .target(name: "CZLib"), 
    .target(name: "Physics", dependencies: ["Helpers"]),
    .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
    .target(name: "Helpers", dependencies: ["Libc", 
      .byName(name: "CZLib", condition: .when(platforms: [.linux])),
      .product(name: "PythonKit", package: "PythonKit")])
  ]
)
