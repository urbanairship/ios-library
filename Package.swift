// swift-tools-version:6.0

// Copyright Airship and Contributors

import PackageDescription

// Matches the Xcode project, which enables InternalImportsByDefault project-wide.
// This makes imports internal unless explicitly marked `public import`, so that
// modules are only re-exposed when actually used in public API.
let airshipSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("InternalImportsByDefault")
]

let package = Package(
    name: "Airship",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .tvOS(.v18), .visionOS(.v1)],
    products: [
        .library(
            name: "AirshipCore",
            targets: ["AirshipCore"]
        ),
        .library(
            name: "AirshipAutomation",
            targets: ["AirshipAutomation"]
        ),
        .library(
            name: "AirshipMessageCenter",
            targets: ["AirshipMessageCenter"]
        ),
        .library(
            name: "AirshipNotificationServiceExtension",
            targets: ["AirshipNotificationServiceExtension"]
        ),
        .library(
            name: "AirshipPreferenceCenter",
            targets: ["AirshipPreferenceCenter"]
        ),
        .library(
            name: "AirshipFeatureFlags",
            targets: ["AirshipFeatureFlags"]
        ),
        .library(
            name: "AirshipObjectiveC",
            targets: ["AirshipObjectiveC"]
        ),
        .library(
            name: "AirshipDebug",
            targets: ["AirshipDebug"]
        ),
        .library(
            name: "AirshipSceneRenderer",
            targets: ["AirshipSceneRenderer"]
        ),
        .library(
            name: "AirshipScenes",
            targets: ["AirshipScenes"]
        ),
        .library(
            name: "AirshipFoundationModels",
            targets: ["AirshipFoundationModels"]
        ),
    ],
    targets: [
        .target(
            name: "AirshipBasement",
            path: "Airship/AirshipBasement",
            exclude: [
                "Info.plist",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipCore",
            dependencies: [.target(name: "AirshipBasement")],
            path: "Airship/AirshipCore",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipAutomation",
            dependencies: [
                .target(name: "AirshipCore"),
                .target(name: "AirshipScenes"),
            ],
            path: "Airship/AirshipAutomation",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipMessageCenter",
            dependencies: [
                .target(name: "AirshipCore"),
                .target(name: "AirshipScenes"),
            ],
            path: "Airship/AirshipMessageCenter",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipNotificationServiceExtension",
            path: "AirshipExtensions/AirshipNotificationServiceExtension",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipPreferenceCenter",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipPreferenceCenter",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipFeatureFlags",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipFeatureFlags",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipObjectiveC",
            dependencies: [
                .target(name: "AirshipBasement"),
                .target(name: "AirshipCore"),
                .target(name: "AirshipPreferenceCenter"),
                .target(name: "AirshipMessageCenter"),
                .target(name: "AirshipAutomation"),
                .target(name: "AirshipFeatureFlags")
            ],
            path: "Airship/AirshipObjectiveC",
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipDebug",
            dependencies: [
                .target(name: "AirshipCore"),
                .target(name: "AirshipPreferenceCenter"),
                .target(name: "AirshipMessageCenter"),
                .target(name: "AirshipAutomation"),
                .target(name: "AirshipSceneRenderer"),
                .target(name: "AirshipScenes"),
                .target(name: "AirshipFeatureFlags")
            ],
            path: "Airship/AirshipDebug",
            exclude: [
                "Info.plist",
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipSceneRenderer",
            dependencies: [.target(name: "AirshipBasement")],
            path: "Airship/AirshipSceneRenderer",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipScenes",
            dependencies: [
                .target(name: "AirshipCore"),
                .target(name: "AirshipSceneRenderer"),
            ],
            path: "Airship/AirshipScenes",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
        .target(
            name: "AirshipFoundationModels",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipFoundationModels",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            swiftSettings: airshipSwiftSettings
        ),
    ]
)
