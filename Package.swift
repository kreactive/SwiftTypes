// swift-tools-version:5.1

import PackageDescription

let pkg = Package(name: "SwiftTypes")
pkg.products = [
    .library(name: "SwiftTypes", targets: ["SwiftTypes"]),
]

let pmk: Target = .target(name: "SwiftTypes")
pmk.path = "SwiftTypes"
pkg.swiftLanguageVersions = [.v5]
pkg.targets = [
    pmk,
    .testTarget(name: "SwiftTypesTests", dependencies: ["SwiftTypes"], path: "SwiftTypesTests"),
]
