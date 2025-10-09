# Airship iOS SDK

[![Swift Package Manager](https://img.shields.io/badge/SPM-supported-DE5C43.svg)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/cocoapods/v/Airship.svg)](https://cocoapods.org/pods/Airship)
[![Carthage](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

The Airship SDK for iOS provides a comprehensive way to integrate Airship's customer experience platform into your iOS, tvOS, and visionOS applications.

## Features
- **Push Notifications** - Rich, interactive push notifications with deep linking
- **Live Activities** - Real-time updates for iOS 16.1+ Dynamic Island and Lock Screen widgets
- **In-App Experiences** - Contextual messaging and automation
- **Message Center** - Inbox for push notifications and messages
- **Preference Center** - User preference management
- **Feature Flags** - Dynamic feature toggles and experimentation
- **Analytics** - Comprehensive user behavior tracking
- **Contacts** - User identification and contact management
- **Tags, Attributes & Subscription Lists** - User segmentation, personalization, and subscription management
- **Privacy Controls** - Granular data collection and feature management
- **SwiftUI Support** - Modern SwiftUI components and views

## Platform Support

| Feature                                | iOS | tvOS | visionOS |
|----------------------------------------|-----|------|----------|
| Push Notifications                     | ✅  | ✅   | ✅        |
| Live Activities                        | ✅  | ❌   | ❌        |
| In-App Experiences                     | ✅  | ❌   | ✅        |
| Message Center                         | ✅  | ❌   | ✅        |
| Preference Center                      | ✅  | ✅   | ✅        |
| Feature Flags                          | ✅  | ✅   | ✅        |
| Analytics                              | ✅  | ✅   | ✅        |
| Contacts                               | ✅  | ✅   | ✅        |
| Tags, Attributes & Subscription Lists  | ✅  | ✅   | ✅        |
| Privacy Controls                       | ✅  | ✅   | ✅        |
| SwiftUI Support                        | ✅  | ✅   | ✅        |

## Installation

Add the Airship iOS SDK to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/urbanairship/ios-library.git", from: "20.0.0")
]
```

In Xcode, add the following products to your target dependencies:
- `AirshipCore` (required)
- `AirshipMessageCenter` (for Message Center)
- `AirshipPreferenceCenter` (for Preference Center)
- `AirshipAutomation` (for In-App Experiences, including Scenes, In-App Automation, and Landing Pages)
- `AirshipFeatureFlags` (for Feature Flags)
- `AirshipNotificationServiceExtension` (for rich push notifications)
- `AirshipObjectiveC` (for Objective-C compatibility)
- `AirshipDebug` (for debugging tools)

## Quick Start

1. **Configure and Initialize Airship** in your `AppDelegate` or `App`:
```swift
import AirshipCore

// In AppDelegate
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    var config = AirshipConfig()
    config.defaultAppKey = "YOUR_APP_KEY"
    config.defaultAppSecret = "YOUR_APP_SECRET"
    
    Airship.takeOff(config)
    return true
}

// Or in SwiftUI App
@main
struct MyApp: App {
    init() {
        var config = AirshipConfig()
        config.defaultAppKey = "YOUR_APP_KEY"
        config.defaultAppSecret = "YOUR_APP_SECRET"
        
        Airship.takeOff(config)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

2. **Enable & Request User Notifications**:
```swift
await Airship.push.enableUserPushNotifications()
```

## Requirements

- iOS 16.0+
- tvOS 18.0+
- visionOS 1.0+
- Xcode 26.0+

## Documentation

- **[Getting Started](https://docs.airship.com/platform/mobile/setup/sdk/ios/)** - Complete setup guide
- **[API Reference](https://docs.airship.com/platform/mobile/resources/api-references/#ios-api-references)** - Full API documentation
- **[Migration Guides](Documentation/Migration/README.md)** - Comprehensive migration documentation
- **[Sample Apps](https://github.com/urbanairship/apple-sample-apps)** - Example implementations

## Support

- 📚 [Documentation](https://docs.airship.com/)
- 🐛 [Report Issues](https://github.com/urbanairship/ios-library/issues)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
