/* Copyright Airship and Contributors */

import Foundation

/// Allowed SDK extension types.
/// - Note: For internal use only. :nodoc:
@objc(UASDKExtension)
public enum AirshipSDKExtension: Int {
    /// The Cordova SDK extension.
    case cordova = 0
    /// The Xamarin SDK extension.
    case xamarin = 1
    /// The Unity SDK extension.
    case unity = 2
    /// The Flutter SDK extension.
    case flutter = 3
    /// The React Native SDK extension.
    case reactNative = 4
    /// The Titanium SDK extension.
    case titanium = 5
    /// The Capacitor SDK extension.
    case capacitor = 6
}

extension AirshipSDKExtension {
    var name: String {
        switch self {
        case .cordova:
            return "cordova"
        case .xamarin:
            return "xamarin"
        case .unity:
            return "unity"
        case .flutter:
            return "flutter"
        case .reactNative:
            return "react-native"
        case .titanium:
            return "titanium"
        case .capacitor:
            return "capacitor"
        }
    }
}
