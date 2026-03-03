// swift-tools-version:6.0

// Copyright Airship and Contributors

import PackageDescription

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
    ],
    targets: [
        .target(
            name: "AirshipBasement",
            path: "Airship/AirshipBasement",
            exclude: [
                "Info.plist",
            ],
            sources: ["Source"]
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
            ]
        ),
        .target(
            name: "AirshipAutomation",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipAutomation",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AirshipMessageCenter",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipMessageCenter",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "AirshipNotificationServiceExtension",
            path: "AirshipExtensions/AirshipNotificationServiceExtension",
            exclude: [
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"]
        ),
        .target(
            name: "AirshipPreferenceCenter",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipPreferenceCenter",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"]
        ),
        .target(
            name: "AirshipFeatureFlags",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipFeatureFlags",
            exclude: [
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"]
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
            sources: ["Source"]
        ),
        .target(
            name: "AirshipDebug",
            dependencies: [
                .target(name: "AirshipCore"),
                .target(name: "AirshipPreferenceCenter"),
                .target(name: "AirshipMessageCenter"),
                .target(name: "AirshipAutomation"),
                .target(name: "AirshipFeatureFlags")
            ],
            path: "Airship/AirshipDebug",
            exclude: [
                "Info.plist",
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
