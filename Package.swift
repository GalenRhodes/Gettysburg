// swift-tools-version:5.4
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
        .package(name: "Rubicon", url: "https://github.com/GalenRhodes/Rubicon.git", .upToNextMinor(from: "0.2.54")),
    ],
    targets: [
        .target(name: "Gettysburg", dependencies: [ "Rubicon" ], exclude: [ "Info.plist", ]),
        .testTarget(name: "GettysburgTests", dependencies: [ "Gettysburg" ], exclude: [ "Info.plist", ], resources: [ .copy("TestData"), ]),
    ])
//@f:1
