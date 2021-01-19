// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Gettysburg",
  platforms: [ .macOS(.v10_15), .tvOS(.v13), .iOS(.v13), .watchOS(.v6) ],
  products: [
      .library(name: "Gettysburg", targets: [ "Gettysburg" ]),
  ],
  dependencies: [ .package(name: "Rubicon", url: "https://github.com/GalenRhodes/Rubicon", from: "0.3.5"), ],
  targets: [
      .target(name: "Gettysburg", dependencies: [ "Rubicon" ]),
      .testTarget(name: "GettysburgTests", dependencies: [ "Gettysburg" ]),
  ]
)
