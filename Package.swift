// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

//@f:0
let package = Package(
    name: "Gettysburg",
    platforms: [ .macOS(.v10_15), .tvOS(.v13), .iOS(.v13), .watchOS(.v6) ],
    products: [
        .library(name: "Gettysburg", targets: [ "Gettysburg" ]),
    ],
    dependencies: [
        .package(name: "Rubicon", url: "https://github.com/GalenRhodes/Rubicon.git", .upToNextMajor(from: "0.1.26")),
    ],
    targets: [
        .target(name: "Gettysburg", dependencies: [ "Rubicon" ], resources: [ .copy("Info.plist") ]),
        .testTarget(name: "GettysburgTests", dependencies: [ "Gettysburg" ], resources: [ .copy("Info.plist"), .copy("TestData") ]),
    ])
//@f:1
