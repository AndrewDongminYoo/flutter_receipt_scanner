// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_receipt_scanner_ios",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "flutter-receipt-scanner-ios", targets: ["flutter_receipt_scanner_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_receipt_scanner_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
