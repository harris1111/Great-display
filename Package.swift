// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GreatDisplay",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GreatDisplay", targets: ["GreatDisplay"]),
    ],
    targets: [
        .target(
            name: "GDCBridge",
            path: "Sources/GDCBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "GDCore",
            dependencies: ["GDCBridge"],
            path: "Sources/GDCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("ColorSync"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        .executableTarget(
            name: "GreatDisplay",
            dependencies: ["GDCore"],
            path: "Sources/GreatDisplay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ],

)
