// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Steppe",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HerdrKit", targets: ["HerdrKit"]),
        .executable(name: "steppe-spike", targets: ["SteppeSpike"]),
        .executable(name: "herdr-probe", targets: ["HerdrProbe"]),
    ],
    targets: [
        .target(name: "HerdrKit"),
        .executableTarget(
            name: "SteppeSpike",
            dependencies: ["HerdrKit"]
        ),
        .executableTarget(
            name: "HerdrProbe",
            dependencies: ["HerdrKit"]
        ),
        .testTarget(
            name: "HerdrKitTests",
            dependencies: ["HerdrKit"]
        ),
    ]
)
