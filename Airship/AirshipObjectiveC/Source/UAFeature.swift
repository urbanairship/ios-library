/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Bindings for `AirshipFeature`
@objc
public final class UAFeature: NSObject, OptionSet, Sendable {
    public let rawValue: UInt

    /// Bindings for `AirshipFeature.inAppAutomation`
    @objc
    public static let inAppAutomation = UAFeature(rawValue: AirshipFeature.inAppAutomation.rawValue)

    /// Bindings for `AirshipFeature.messageCenter`
    @objc
    public static let messageCenter = UAFeature(rawValue: AirshipFeature.messageCenter.rawValue)

    /// Bindings for `AirshipFeature.push`
    @objc
    public static let push = UAFeature(rawValue: AirshipFeature.push.rawValue)

    /// Bindings for `AirshipFeature.analytics`
    @objc
    public static let analytics = UAFeature(rawValue: AirshipFeature.analytics.rawValue)

    /// Bindings for `AirshipFeature.tagsAndAttributes`
    @objc
    public static let tagsAndAttributes = UAFeature(rawValue: AirshipFeature.tagsAndAttributes.rawValue)

    /// Bindings for `AirshipFeature.contacts`
    @objc
    public static let contacts = UAFeature(rawValue: AirshipFeature.contacts.rawValue)

    /// Bindings for `AirshipFeature.featureFlags`
    @objc
    public static let featureFlags = UAFeature(rawValue: AirshipFeature.featureFlags.rawValue)

    /// All features
    @objc
    public static let all: UAFeature = [
        inAppAutomation,
        messageCenter,
        push,
        analytics,
        tagsAndAttributes,
        contacts,
        featureFlags
    ]

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

extension UAFeature {
    var asAirshipFeature: AirshipFeature {
        return AirshipFeature(rawValue: self.rawValue)
    }
}

extension AirshipFeature {
    var asUAFeature: UAFeature {
        return UAFeature(rawValue: self.rawValue)
    }
}
