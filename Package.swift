// swift-tools-version:4.0

import PackageDescription

let pkg = Package(name: "SwiftTypes")
pkg.products = [
    .library(name: "SwiftTypes", targets: ["SwiftTypes"]),
]

let pmk: Target = .target(name: "SwiftTypes")
pmk.path = "SwiftTypes"
pkg.swiftLanguageVersions = [5]
pkg.targets = [
    pmk,
    .testTarget(name: "SwiftTypesTests", dependencies: ["SwiftTypes"]),
]
