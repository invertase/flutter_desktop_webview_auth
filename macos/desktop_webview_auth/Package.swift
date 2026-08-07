// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "desktop_webview_auth",
    platforms: [
        .macOS("10.14")
    ],
    products: [
        .library(name: "desktop-webview-auth", targets: ["desktop_webview_auth"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "desktop_webview_auth",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
