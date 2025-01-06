// swift-tools-version:6.0

// Copyright Airship and Contributors

import PackageDescription

let package = Package(
    name: "Airship",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v15), .tvOS(.v18), .visionOS(.v1)],
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
            name: "AirshipWrapper",
            targets: ["AirshipWrapper"]
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
                "Source/Public/AirshipBasement.h",
                "Info.plist",
            ],
            sources: ["Source"],
            publicHeadersPath: "Source/Public",
            cSettings: [
                .headerSearchPath("Source/Internal")
            ],
            linkerSettings: [
                //Frameworks
                .linkedFramework("UserNotifications"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreData"),
                .linkedFramework("WebKit", .when(platforms: [.iOS, .visionOS])),
                .linkedFramework("CoreTelephony", .when(platforms: [.iOS])),
                //Libraries
                .linkedLibrary("z"),
                .linkedLibrary("sqlite3"),
            ]
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
            linkerSettings: [
                //Frameworks
                .linkedFramework("UserNotifications"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("UIKit"),
                .linkedFramework("CoreData"),
                .linkedFramework("WebKit", .when(platforms: [.iOS, .visionOS])),
                .linkedFramework("CoreTelephony", .when(platforms: [.iOS])),
                .linkedFramework("StoreKit", .when(platforms: [.iOS, .visionOS])),
                //Libraries
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "AirshipAutomation",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipAutomation",
            exclude: [
                "Source/AirshipAutomation.h",
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
                "Source/AirshipMessageCenter.h",
                "Info.plist",
                "Tests"
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ],
            publicHeadersPath: "Source/Public",
            cSettings: [
                .headerSearchPath("Source"),
                .headerSearchPath("Source/Inbox"),
                .headerSearchPath("Source/Inbox/Data"),
                .headerSearchPath("Source/User"),
            ]
        ),
        .target(
            name: "AirshipNotificationContentExtension",
            path: "AirshipExtensions/AirshipNotificationContentExtension",
            exclude: [
                "Source/AirshipNotificationContentExtension.h",
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            publicHeadersPath: "Source/Public"
        ),
        .target(
            name: "AirshipNotificationServiceExtension",
            path: "AirshipExtensions/AirshipNotificationServiceExtension",
            exclude: [
                "Source/AirshipNotificationServiceExtension.h",
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"],
            publicHeadersPath: "Source"
        ),
        .target(
            name: "AirshipPreferenceCenter",
            dependencies: [.target(name: "AirshipCore")],
            path: "Airship/AirshipPreferenceCenter",
            exclude: [
                "Source/AirshipPreferenceCenter.h",
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
                "Source/AirshipFeatureFlags.h",
                "Info.plist",
                "Tests",
            ],
            sources: ["Source"]
        ),
	.target(
            name: "AirshipWrapper",
            dependencies: [
		.target(name: "AirshipBasement"),
                .target(name: "AirshipCore"),
                .target(name: "AirshipPreferenceCenter"),
                .target(name: "AirshipMessageCenter"),
                .target(name: "AirshipAutomation"),
                .target(name: "AirshipFeatureFlags")
            ],
            path: "Airship/AirshipWrapper",
            exclude: [
                "AirshipWrapper.h"
            ],
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
                "Source/AirshipDebug.h",
                "Info.plist",
            ],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)