# Airship iOS SDK Migration Guide

# Airship SDK 14.4 to 14.5

Airship SDK 14.5 is a minor update that changes how the SDK handles data collection by introducing the
privacy manager. Privacy manager allows fine-grained control over what data is allowed to be collected
or accessed by the Airship SDK. In addition to better control, if all features are disabled in the privacy
manager, the SDK will no-op.

The privacy manager can be accessed from the shared `UAirship` instance:

Objective-c:
```objective-c
UAPrivacyManager *privacyManager = [[UAirship shared].privacyManager;
```
Swift:
```swift
let privacyManager = UAirship.shared().privacyManager
```

## Enabling & Disabling Data Collection

To enable data collection set enabled features to `UAFeaturesAll`:

Objective-c:
```objective-c
  // Deprecated
  [UAirship shared].dataCollectionEnabled = YES;

  // Replacement
  [UAirship shared].privacyManager.enabledFeatures = UAFeaturesAll;
```

Swift:
```swift
  // Deprecated
  UAirship.shared().isDataCollectionEnabled = true

  // Replacement
  UAirship.shared().privacyManager.enable(UAFeatures.all)
```

To disable data collection set enabled features to `UAFeaturesNone`:

Objective-c:
```objective-c
  // Deprecated
  [UAirship shared].dataCollectionEnabled = NO;

  // Replacement
  [UAirship shared].privacyManager.enabledFeatures = UAFeaturesNone;
```

Swift:
```swift
  // Deprecated
  UAirship.shared().isDataCollectionEnabled = false

  // Replacement
  UAirship.shared().privacyManager.enabledFeatures = []
```

The behavior prior to SDK 14.5 would still allow broadcasts in In-App Automation and Message Center.
To keep that behavior, set the enabled features to `UAFeaturesMessageCenter` and `UAFeaturesInAppAutomation` instead of `UAFeaturesNone`:

Objective-c:
```objective-c
  [UAirship shared].privacyManager.enabledFeatures = UAFeaturesMessageCenter | UAInAppAutomation;
```

Swift:
```swift
  UAirship.shared().privacyManager.enabledFeatures = [.messageCenter, .inAppAutomation]
```

## Enabling Data Collection Opt-In

The flag `dataCollectionOptInEnabled` is deprecated and replaced with `enabledFeatures`.
To start the SDK in a fully opted out state, set `enabledFeatures` to `UAFeaturesNone` in the `AirshipConfig.plist`
file or directly on the config object:

Objective-c:
```objective-c
  UAConfig *config = [UAConfig defaultConfig];
  config.enabledFeatures = UAFeaturesNone;
```

Swift:
```swift
  let config = UAConfig.defaultConfig()
  config.enabedFeatures = []
```

This will start the SDK in a completely opted out state.

## Enabling & Disabling Push Token Registration

When data collection was disabled, it was still possible to allow push registration with a separate
flag. With privacy manager, you can now just specify `UAFeaturesPush` to continue to allow token
registration.

Enabling:

Objective-c:
```objective-c
  // Deprecated
  [UAirship push].pushTokenRegistrationEnabled = YES;

  // Replacement
  [[UAirship shared].privacyManager enableFeatures:UAFeaturesPush];
```

Swift:
```swift
  // Deprecated
  UAirship.push().pushTokenRegistrationEnabled = true

  // Replacement
  UAirship.shared().privacyManager.enable(UAFeatures.push)
```

Disabling:

Objective-c:
```objective-c
  // Deprecated
  [UAirship push].pushTokenRegistrationEnabled = NO;

  // Replacement
  [[UAirship shared].privacyManager disableFeatures:UAFeaturesPush];
```

Swift:
```swift
  // Deprecated
  UAirship.push().pushTokenRegistrationEnabled = false

  // Replacement
  UAirship.shared().privacyManager.disable(UAFeatures.push)
```

Checking if enabled:

Objective-c:
```objective-c
  // Deprecated
  [UAirship push].pushTokenRegistrationEnabled;

  // Replacement
  [[UAirship shared].privacyManager isEnabled:UAFeaturesPush];
```

Swift:
```swift
  // Deprecated
  UAirship.push().pushTokenRegistrationEnabled

  // Replacement
  UAirship.shared().privacyManager.isEnabled(UAFeatures.push)
```

# Enabling Analytics

Analytics had an additional `enabled` flag that is now deprecated and replaced with `UAFeaturesAnalytics`
on the privacy manager.

Enabling:

Objective-c:
```objective-c
  // Deprecated
  [UAirship analytics].enabled = YES;

  // Replacement
  [[UAirship shared].privacyManager enableFeatures:UAFeaturesAnalytics;
```

Swift:
```swift
  // Deprecated
  UAirship.analytics().isEnabled = true

  // Replacement
  UAirship.shared().privacyManager.enable(UAFeatures.analytics)
```

Disabling:

Objective-c:
```objective-c
  // Deprecated
  [UAirship analytics].enabled = NO;

  // Replacement
  [[UAirship shared].privacyManager disableFeatures:UAFeaturesAnalytics;
```

Swift:
```swift
  // Deprecated
  UAirship.analytics().isEnabled = false

  // Replacement
  UAirship.shared().privacyManager.disable(UAFeatures.analytics)
```

Checking if enabled:

Objective-c:
```objective-c
  // Deprecated
  [UAirship analytics].enabled;

  // Replacement
  [[UAirship shared].privacyManager isEnabled:UAFeaturesAnalytics;
```

Swift:
```swift
  // Deprecated
  UAirship.analytics().isEnabled

  // Replacement
  UAirship.shared().privacyManager.isEnabled(UAFeatures.analytics)
```

Analytics can still be completely disabled through `UAConfig` and `AirshipConfig.plist`. If disabled through config, `enabled` will always return `NO` regardless of privacy manager settings.
