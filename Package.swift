// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

//@f:0
let package = Package(
    name: "Gettysburg",
    platforms: [ .macOS(.v10_15), .tvOS(.v13), .iOS(.v13), .watchOS(.v6) ],
    products: [
        .library(name: "Gettysburg", targets: [ "Gettysburg" ]),
        .executable(name: "URLSessionTester", targets: [ "URLSessionTester" ]),
    ],
    dependencies: [
        .package(name: "Rubicon", url: "https://github.com/GalenRhodes/Rubicon.git", .upToNextMinor(from: "0.3.2")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.3")),
    ],
    targets: [
        .target(name: "Gettysburg", dependencies: [ "Rubicon" ], exclude: [ "Info.plist", ]),
        .executableTarget(name: "URLSessionTester", dependencies: [ "Rubicon", .product(name: "ArgumentParser", package: "swift-argument-parser"), ]),
        .testTarget(name: "GettysburgTests", dependencies: [ "Gettysburg" ], exclude: [ "Info.plist", ], resources: [ .copy("TestData"), ]),
    ])
//@f:1
