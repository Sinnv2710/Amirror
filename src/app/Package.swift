// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Amirror",
    platforms: [
        .macOS("13.0")
    ],
    products: [
        .executable(name: "Amirror", targets: ["Amirror"])
    ],
    targets: [
        .executableTarget(
            name: "Amirror",
            dependencies: [],
            path: "."
        )
    ]
)
