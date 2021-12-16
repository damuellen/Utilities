// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [.macOS(.v10_15), .iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Utilities",
            targets: ["Utilities"]),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-numerics.git", from: "1.0.0")
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "Utilities", dependencies: ["Helpers", "Physics"]),
        .target(name: "Libc"),
        .target(name: "Helpers",
          dependencies: ["Libc", .product(name: "Numerics", package: "swift-numerics")]),
        .target(name: "Physics",
          dependencies: ["Helpers", "CIAPWSIF97"]),
        .target(name: "CIAPWSIF97")
    ]
)
