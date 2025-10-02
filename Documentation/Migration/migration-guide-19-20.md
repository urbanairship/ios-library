# Airship iOS SDK 19.x to 20.0 Migration Guide

The Airship SDK 20.0 introduces major architectural changes including UI refactors for Message Center and Preference Center, a protocol-first architecture for core components, and modern block-based callback alternatives to delegate patterns. The minimum deployment target is raised to iOS 16+. This guide outlines the necessary changes for migrating your app from SDK 19.x to SDK 20.0.

**Required Migration Tasks:**
- Update Xcode to 26+
- Update deployment target to iOS 16+
- Update SwiftUI view calls for Message Center/Preference Center

**Optional Migration Tasks:**
- Migrate delegate patterns to block-based callbacks
- Update deprecated API calls to new APIs

## Table of Contents

- [Breaking Changes](#breaking-changes)
  - [Preference Center Refactor](#preference-center-refactor)
  - [Message Center Refactor](#message-center-refactor)
  - [Protocol Architecture Changes](#protocol-architecture-changes)
- [Deprecated APIs](#deprecated-apis)
  - [Attribute Management](#attribute-management)
  - [Preference Center Display](#preference-center-display)
- [Block-Based Callbacks](#block-based-callbacks)
  - [Push Notifications](#push-notifications)
  - [Registration](#registration)
  - [Deep Links](#deep-links)
  - [URL Allow List](#url-allow-list)
  - [Displaying the Message Center](#displaying-the-message-center)
  - [Displaying the Preference Center](#displaying-the-preference-center)
  - [In-App Messaging Display Control](#in-app-messaging-display-control)
- [Troubleshooting](#troubleshooting)

## Breaking Changes

### Preference Center Refactor

The Preference Center has been refactored to provide clearer separation between content and navigation, and to simplify customization.

#### View Hierarchy Changes

The Preference Center now follows a "Container vs. Content" architecture that separates navigation from content. The main view `PreferenceCenterView` is now a wrapper that provides a `NavigationStack`. The core content, previously known as `PreferenceCenterList`, has been renamed to `PreferenceCenterContent`.

- **`PreferenceCenterView`**: This is the container view. It sets up the `NavigationStack` and is responsible for the navigation bar's title and back button. Use this view for a standard Preference Center implementation with navigation.
- **`PreferenceCenterContent`**: This is the content view. It loads and displays the list of preferences. Use this view if you want to provide your own navigation or embed the Preference Center within another view.

#### API Updates

Several types and protocols have been renamed for clarity:

- `PreferenceCenterList` → `PreferenceCenterContent`
- `PreferenceCenterViewPhase` → `PreferenceCenterContentPhase`
- `PreferenceCenterViewLoader` → `PreferenceCenterContentLoader`
- `PreferenceCenterViewStyle` → `PreferenceCenterContentStyle`
- `PreferenceCenterViewStyleConfiguration` → `PreferenceCenterContentStyleConfiguration`


#### Navigation Changes

The `PreferenceCenterNavigationStack` enum and the `preferenceCenterNavigationStack()` view modifier have been removed. `PreferenceCenterView` now always uses a `NavigationStack`. If you were previously using `.none`, you should switch to using `PreferenceCenterContent` directly.

**Before:**
```swift
// To provide custom navigation
PreferenceCenterView(preferenceCenterID: "your_id")
    .preferenceCenterNavigationStack(.none)
```

**After:**
```swift
// Use PreferenceCenterContent directly
PreferenceCenterContent(preferenceCenterID: "your_id")
```

### Message Center Refactor

The Message Center UI has been refactored for greater flexibility and clearer API boundaries, separating navigation from content.

#### View Hierarchy Changes

The Message Center now follows a "Container vs. Content" architecture that separates navigation from content. The top-level `MessageCenterView` is now a navigation container. The actual content is rendered by `MessageCenterContent`.

The Message Center UI is broken down into several public components that can be used to build a custom experience:

- **`MessageCenterView`**: The top-level container that provides a `NavigationStack` or `NavigationSplitView`. Use this view for a standard Message Center implementation. It provides either a `NavigationStack` or a `NavigationSplitView`, which can be controlled via the new `navigationStyle` parameter.
- **`MessageCenterContent`**: The core content view that coordinates the message list. Use this view if you need to provide your own navigation or embed the Message Center within a custom view hierarchy.
- **`MessageCenterListViewWithNavigation`**: This view displays the list of messages and **is responsible for the navigation bar content**, including the title and the edit/toolbar buttons.
- **`MessageCenterListView`**: A simpler view that only displays the list of messages, without any navigation bar items.
- **`MessageCenterMessageViewWithNavigation`**: Displays a single message and manages its navigation bar.
- **`MessageCenterMessageView`**: Displays a single message without a navigation bar.

#### API Updates

- `MessageCenterViewStyle` → `MessageCenterContentStyle`
- `messageCenterViewStyle()` → `messageCenterContentStyle()`
- `MessageCenterStyleConfiguration` → `MessageCenterContentStyleConfiguration`

#### Navigation Changes

The `MessageCenterNavigationStack` enum and the `messageCenterNavigationStack()` view modifier have been removed. Navigation is now controlled by the `navigationStyle` parameter on `MessageCenterView`.

**Before:**
```swift
// Basic Message Center
MessageCenterView()

// With custom navigation
MessageCenterView()
    .messageCenterNavigationStack(.none)
```

**After:**
```swift
// Stack-based navigation (default on iPhone)
MessageCenterView(navigationStyle: .stack)

// Split-view navigation (default on iPad)
MessageCenterView(navigationStyle: .split)

// To provide custom navigation, use MessageCenterContent
MessageCenterContent()
```

### Protocol Architecture Changes

SDK 20.0 refactors core Airship components to use protocols instead of concrete classes. The existing functionality remains the same, but the implementation is now hidden behind protocol interfaces. This change provides better testability, modularity, and allows for easier customization and mocking.

#### Class-to-Protocol Conversions

Several core Airship classes have been converted to protocols (with the same functionality):

- `AirshipPrivacyManager`
- `AirshipPermissionsManager`
- `MessageCenter`
- `InAppAutomation`
- `PreferenceCenter`
- `InAppMessaging`
- `LegacyInAppMessaging`
- `AirshipActionRegistry`
- `AirshipChannelCapture`
- `FeatureFlagManager`

#### Protocol Renames

Several protocols have been renamed to remove the "Protocol" suffix:

- `AirshipAnalyticsProtocol` → `AirshipAnalytics`
- `AirshipChannelProtocol` → `AirshipChannel`
- `AirshipContactProtocol` → `AirshipContact`
- `AirshipPushProtocol` → `AirshipPush`
- `PrivacyManagerProtocol` → `AirshipPrivacyManager`
- `URLAllowListProtocol` → `AirshipURLAllowList`
- `AirshipLocaleManagerProtocol` → `AirshipLocaleManager`
- `InAppMessagingProtocol` → `InAppMessaging`
- `LegacyInAppMessagingProtocol` → `LegacyInAppMessaging`

#### Migration Impact

**For most developers:** These changes are primarily internal and won't affect your code. The public APIs remain the same - you can continue using `Airship.contact`, `Airship.privacyManager`, `Airship.messageCenter`, `Airship.inAppAutomation`, `Airship.preferenceCenter`, etc. as before.

---

## Deprecated APIs

Several APIs have been deprecated in SDK 20.0 and will be removed in future versions. Update your code to use the recommended alternatives.

### Attribute Management

The `set(number:attribute:)` method now accepts Swift numeric types directly instead of `NSNumber`. This change is **backward compatible** - existing code using `Int` or `UInt` literals will continue to work without modification.

**Before:**
```swift
// Old method using NSNumber
Airship.contact.editAttributes { editor in
    editor.set(number: NSNumber(value: 42), attribute: "age")
}
```

**After:**
```swift
// Use Swift types - Int, Uint, or Double
Airship.contact.editAttributes { editor in
    editor.set(number: 42, attribute: "age")
    editor.set(number: 42.0, attribute: "age")
    editor.set(number: UInt(42), attribute: "age")
}
```

### Preference Center Display

**Before:**
```swift
// Old method
Airship.preferenceCenter.openPreferenceCenter(preferenceCenterID: "my_id")
```

**After:**
```swift
// New method
Airship.preferenceCenter.display("my_id")
```

---

## Block-Based Callbacks

To provide a more modern and convenient Swift API, SDK 20 introduces block-based (closure) callbacks as an alternative to several common delegate protocols. These new callbacks improve code locality and can reduce boilerplate for simple event handling.

The delegate-based approach is still fully supported, but we recommend adopting the new block-based callbacks for new implementations. **The delegate patterns will be deprecated in a future 20.x release and removed in SDK 21.0.0**

All new callback closures are `@MainActor` and `@Sendable` to ensure thread safety and simplify UI updates.

### Push Notifications

Instead of conforming to `PushNotificationDelegate`, you can now set individual closures on `Airship.push`. If a block is provided for a specific event, the corresponding `PushNotificationDelegate` method will be ignored.

**Before:**
```swift
// A class that implements the delegate
class MyPushDelegate: PushNotificationDelegate {
    func receivedNotificationResponse(_ response: UNNotificationResponse) async {
        // Handle response asynchronously
        await someAsyncTask()
    }
    // ... other delegate methods
}

// In your app, store a strong reference to the delegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let pushDelegate = MyPushDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.push.pushNotificationDelegate = pushDelegate
        return true
    }
}
```

**After:**
```swift
// In your app's startup code
Airship.push.onReceivedNotificationResponse = { response in
    // Handle response asynchronously
    await someAsyncTask()
}
```

**New APIs on `Airship.push`:**
- `onReceivedForegroundNotification`
- `onReceivedBackgroundNotification`
- `onReceivedNotificationResponse`
- `onExtendPresentationOptions`

### Registration

The `RegistrationDelegate` has also been broken down into more granular, event-specific closures. If a block is provided, it will be used instead of the corresponding delegate method.

**Before:**
```swift
// A class that implements the delegate
class MyRegistrationDelegate: RegistrationDelegate {
    func apnsRegistrationSucceeded(withDeviceToken deviceToken: Data) {
        print("APNs registration succeeded")
    }

    func notificationRegistrationFinished(
        withAuthorizedSettings authorizedSettings: AirshipAuthorizedNotificationSettings,
        status: UNAuthorizationStatus
    ) {
        print("Notification registration finished with status: \(status)")
    }
}

// In your app, store a strong reference to the delegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let registrationDelegate = MyRegistrationDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.push.registrationDelegate = registrationDelegate
        return true
    }
}
```

**After:**
```swift
// In your app's startup code

// Handle APNS registration updates
Airship.push.onAPNSRegistrationFinished = { result in
    switch result {
    case .success(let deviceToken):
        print("APNs registration succeeded: \(deviceToken)")
    case .failure(let error):
        print("APNs registration failed: \(error)")
    }
}

// Handle user notification registration updates
Airship.push.onNotificationRegistrationFinished = { result in
    print("Notification registration finished with status: \(result.status)")
}

// Handle changes to authorized notification settings
Airship.push.onNotificationAuthorizedSettingsDidChange = { settings in
    print("Authorized settings changed: \(settings)")
}
```

**New APIs on `Airship.push`:**
- `onAPNSRegistrationFinished` with `APNSRegistrationResult`
- `onNotificationRegistrationFinished` with `NotificationRegistrationResult`
- `onNotificationAuthorizedSettingsDidChange`

The new callbacks use the following data structures:

```swift
/// The result of an APNs registration.
public enum APNSRegistrationResult: Sendable {
    /// Registration was successful and a new device token was received.
    case success(deviceToken: String)

    /// Registration failed.
    case failure(error: any Error)
}

/// The result of the initial notification registration prompt.
public struct NotificationRegistrationResult: Sendable {
    /// The settings that were authorized at the time of registration.
    public let authorizedSettings: AirshipAuthorizedNotificationSettings

    /// The authorization status.
    public let status: UNAuthorizationStatus

    #if !os(tvOS)
    /// Set of the categories that were most recently registered.
    public let categories: Set<UNNotificationCategory>
    #endif
}
```

### Deep Links

Instead of conforming to `DeepLinkDelegate`, you can now set closures on `Airship`. If the `onDeepLink` block is set, the `DeepLinkDelegate` will be ignored.

**Before:**
```swift
class MyDeepLinkDelegate: DeepLinkDelegate {
    func receivedDeepLink(_ deepLink: URL) async {
        // Handle deep link asynchronously
        await someNavigationTask(url)
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let deepLinkDelegate = MyDeepLinkDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.deepLinkDelegate = deepLinkDelegate
        return true
    }
}
```

**After:**
```swift
Airship.onDeepLink = { url in
    // Handle deep link asynchronously
    await someNavigationTask(url)
}
```

**New API on `Airship`:**
- `onDeepLink`

### URL Allow List

Instead of conforming to `URLAllowListDelegate`, you can now set the `onAllowURL` closure on `Airship.urlAllowList`. If the `onAllowURL` block is set, the `URLAllowListDelegate` will be ignored.

**Before:**
```swift
class MyURLDelegate: URLAllowListDelegate {
    func allowURL(_ url: URL, scope: URLAllowListScope) -> Bool {
        // Custom URL validation logic
        return url.host?.contains("trusted-domain.com") == true
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let urlDelegate = MyURLDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ...
        
        // After takeOff
        Airship.urlAllowList.delegate = urlDelegate
        return true
    }
}
```

**After:**
```swift
Airship.urlAllowList.onAllowURL = { url, scope in
    // Custom URL validation logic
    return url.host?.contains("trusted-domain.com") == true
}
```

**New API on `Airship.urlAllowList`:**
- `onAllowURL`

### Displaying the Message Center

Instead of `MessageCenterDisplayDelegate`, you can now use the `onDisplay` and `onDismissDisplay` closures on `Airship.messageCenter`. The `onDisplay` closure should return `true` if the display was handled, or `false` to let the SDK fall back to its default UI. If the `onDisplay` block is set, the delegate will be ignored.

**Before:**
```swift
class MyDisplayDelegate: MessageCenterDisplayDelegate {
    func displayMessageCenter(messageID: String?) {
        // Display Message Center UI
    }

    func dismissMessageCenter() {
        // Dismiss Message Center UI
    }
}

// Store a strong reference
private let displayDelegate = MyDisplayDelegate()

// In your app's startup code
Airship.messageCenter.displayDelegate = displayDelegate
```

**After:**
```swift
Airship.messageCenter.onDisplay = { messageID in
    // Display custom Message Center UI
    // Return true to prevent the default SDK display behavior.
    return true
}

Airship.messageCenter.onDismissDisplay = {
    // Dismiss Message Center UI
}
```

### Displaying the Preference Center

Instead of `PreferenceCenterOpenDelegate`, you can use the new `onDisplay` closure on `Airship.preferenceCenter`. The closure should return `true` if the display was handled, or `false` to let the SDK fall back to its default UI. If the `onDisplay` block is set, the delegate will be ignored.

**Before:**
```swift
class MyOpenDelegate: PreferenceCenterOpenDelegate {
    func openPreferenceCenter(preferenceCenterID: String) {
        // Display Preference Center UI
    }
}

// Store a strong reference
private let openDelegate = MyOpenDelegate()

// In your app's startup code
Airship.preferenceCenter.openDelegate = openDelegate
```

**After:**
```swift
Airship.preferenceCenter.onDisplay = { preferenceCenterID in
    // Display custom Preference Center UI
    // Return true to prevent the default SDK display behavior.
    return true
}
```

**New API on `Airship.preferenceCenter`:**
- `onDisplay`

### In-App Messaging Display Control

Instead of implementing `InAppMessagingDisplayDelegate`, you can now use the `onIsReadyToDisplay` closure on `Airship.inAppMessaging`. This closure allows you to control when in-app messages are ready to be displayed. If the `onIsReadyToDisplay` block is set, the delegate will be ignored.

**Before:**
```swift
class MyDisplayDelegate: InAppMessagingDisplayDelegate {
    func isMessageReadyToDisplay(_ message: InAppMessage, scheduleID: String) -> Bool {
        // Custom logic to determine if message should be displayed
        return someCondition
    }
}

// Store a strong reference
private let displayDelegate = MyDisplayDelegate()

// In your app's startup code
Airship.inAppMessaging.displayDelegate = displayDelegate
```

**After:**
```swift
Airship.inAppMessaging.onIsReadyToDisplay = { message, scheduleID in
    // Custom logic to determine if message should be displayed
    return someCondition
}
```

**New API on `Airship.inAppMessaging`:**
- `onIsReadyToDisplay`

---

## Troubleshooting

### Common Issues

**Build Errors After Migration**
- Ensure you're using Xcode 26+ and have updated your deployment target to iOS 16+
- Clean your build folder (Product → Clean Build Folder) and rebuild
- Check that all SwiftUI view calls have been updated to use the new API names

**Message Center/Preference Center Not Displaying**
- Verify you're using the correct view names (`MessageCenterView` vs `MessageCenterContent`)
- Check that navigation style parameters are set correctly
- Ensure you're not mixing old and new API calls

**Delegate Methods Not Being Called**
- If you've migrated to block-based callbacks, ensure you're not setting both delegates and blocks
- Block-based callbacks take precedence over delegate methods
- Check that your delegate objects are retained (not deallocated)

**Attribute Setting Issues**
- The `set(number:attribute:)` method now accepts Swift types directly
- `Int` and `UInt` values are automatically bridged to `Double`
- If you're still using `NSNumber`, consider migrating to Swift types

### Getting Help

If you encounter issues not covered in this guide:
- Check the [Airship Documentation](https://docs.airship.com/)
- Review the [SDK API Reference](https://docs.airship.com/reference/libraries/ios/)
- Contact [Airship Support](https://support.airship.com/)