# Airship SDK for Apple

[![Swift Package Manager](https://img.shields.io/badge/SPM-supported-DE5C43.svg)](https://swift.org/package-manager/)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

The Airship SDK for Apple provides a comprehensive way to integrate Airship's customer experience platform into your iOS, tvOS, and visionOS applications.

## Features
- **Push Notifications** - Rich, interactive push notifications with deep linking
- **Live Activities** - Real-time updates for iOS 16.1+ Dynamic Island and Lock Screen widgets
- **In-App Experiences** - Contextual messaging and automation
- **Message Center** - Inbox for push notifications and messages
- **Preference Center** - User preference management
- **Feature Flags** - Dynamic feature toggles and experimentation
- **On-Device AI** - Personalize experiences with an on-device model, or route to your own
- **Analytics** - Comprehensive user behavior tracking
- **Contacts** - User identification and contact management
- **Tags, Attributes & Subscription Lists** - User segmentation, personalization, and subscription management
- **Privacy Controls** - Granular data collection and feature management
- **SwiftUI Support** - Modern SwiftUI components and views
- **Swift 6** - Fully adopted Swift 6 with strict concurrency safety

## Platform Support

| Feature                                | iOS | tvOS          | visionOS |
|----------------------------------------|-----|---------------|----------|
| Push Notifications                     | ✅  | ✅             | ✅       |
| Live Activities                        | ✅  | ❌             | ❌       |
| In-App Experiences                     | ✅  | ✅<sup>1</sup> | ✅       |
| Message Center                         | ✅  | ✅<sup>2</sup> | ✅       |
| Preference Center                      | ✅  | ✅             | ✅       |
| Feature Flags                          | ✅  | ✅             | ✅       |
| On-Device AI                           | ✅  | ✅<sup>3</sup> | ✅       |
| Analytics                              | ✅  | ✅             | ✅       |
| Contacts                               | ✅  | ✅             | ✅       |
| Tags, Attributes & Subscription Lists  | ✅  | ✅             | ✅       |
| Privacy Controls                       | ✅  | ✅             | ✅       |
| SwiftUI Support                        | ✅  | ✅             | ✅       |

<sup>1</sup> tvOS In-App Experiences: Scenes, Banners, and non-HTML In-App Automations are supported. However, scheduled In-App Experiences will no longer display if the app’s cache is wiped due to tvOS storage limitations.
<sup>2</sup> tvOS Message Center: Supports Native Message Center.
<sup>3</sup> tvOS On-Device AI: requires a custom model. The AI framework lives in `AirshipCore` and works on every platform and deployment target, but the built-in model ships in the optional `AirshipFoundationModels` module on top of Apple's Foundation Models, which is unavailable on tvOS. The same applies on iOS and visionOS below 26 — supply your own model to serve devices the built-in one can't.

## Installation

Add the Airship SDK to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/urbanairship/ios-library.git", from: "20.4.0")
]
```

In Xcode, add the following products to your target dependencies:
- `AirshipCore` (required)
- `AirshipMessageCenter` (for Message Center)
- `AirshipPreferenceCenter` (for Preference Center)
- `AirshipAutomation` (for In-App Experiences, including Scenes, In-App Automation, and Landing Pages)
- `AirshipFeatureFlags` (for Feature Flags)
- `AirshipFoundationModels` (optional, for the built-in on-device AI model)
- `AirshipNotificationServiceExtension` (for rich push notifications)
- `AirshipObjectiveC` (for Objective-C compatibility)
- `AirshipDebug` (for debugging tools)

For other installation methods (Carthage, xcframeworks), please see the [getting started guide](https://www.airship.com/docs/developer/sdk-integration/apple/installation/getting-started/).

> **Note**: CocoaPods is no longer supported as of SDK 21.0. See the [migration guide](Documentation/Migration/migration-guide-20-21.md) if you are upgrading from 20.x.

## Quick Start

1. **Configure and Initialize Airship** in your `AppDelegate` or `App`:
```swift
import AirshipCore

// In AppDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    var config = AirshipConfig()
    config.defaultAppKey = "YOUR_APP_KEY"
    config.defaultAppSecret = "YOUR_APP_SECRET"
    
    try! Airship.takeOff(config)
    return true
}

// Or in SwiftUI App
@main
struct MyApp: App {
    init() {
        var config = AirshipConfig()
        config.defaultAppKey = "YOUR_APP_KEY"
        config.defaultAppSecret = "YOUR_APP_SECRET"
        
        try! Airship.takeOff(config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

> **Note**: `Airship.takeOff` should only be called once.

2. **Enable & Request User Notifications**:
```swift
await Airship.push.enableUserPushNotifications()
```

## Requirements

- iOS 16.0+
- tvOS 18.0+
- visionOS 1.0+
- Xcode 27.0+

## Documentation

- **[Getting Started](https://www.airship.com/docs/developer/sdk-integration/apple/installation/getting-started/)** - Complete setup guide
- **[API Reference](https://urbanairship.github.io/ios-library/)** - Full API documentation
- **[Migration Guides](Documentation/Migration/README.md)** - Comprehensive migration documentation
- **[Sample Apps](https://github.com/urbanairship/apple-sample-apps)** - Example implementations

## Support

- 📚 [Documentation](https://www.airship.com/docs/)
- 🐛 [Report Issues](https://github.com/urbanairship/ios-library/issues)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
