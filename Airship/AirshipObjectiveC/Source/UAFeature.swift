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
    public static func inAppAutomation() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.inAppAutomation.rawValue)
    }

    /// Bindings for `AirshipFeature.messageCenter`
    @objc
    public static func messageCenter() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.messageCenter.rawValue)
    }

    /// Bindings for `AirshipFeature.push`
    @objc
    public static func push() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.push.rawValue)
    }

    /// Bindings for `AirshipFeature.analytics`
    @objc
    public static func analytics() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.analytics.rawValue)
    }

    /// Bindings for `AirshipFeature.tagsAndAttributes`
    @objc
    public static func tagsAndAttributes() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.tagsAndAttributes.rawValue)
    }

    /// Bindings for `AirshipFeature.contacts`
    @objc
    public static func contacts() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.contacts.rawValue)
    }

    /// Bindings for `AirshipFeature.featureFlags`
    @objc
    public static func featureFlags() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.featureFlags.rawValue)
    }

    /// All features
    @objc
    public static func all() -> UAFeature {
        return UAFeature(rawValue: AirshipFeature.all.rawValue)
    }

    @objc
    public static func none() -> UAFeature {
        return UAFeature(rawValue: 0)
    }

    @objc
    public convenience init(from: [UAFeature]) {
        self.init(from)
    }

    @objc(contains:)
    public func _contains(_ feature: UAFeature) -> Bool {
        return self.contains(feature)
    }

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public override var hash: Int {
          return Int(rawValue)
      }

      public override func isEqual(_ object: Any?) -> Bool {
          guard let that = object as? UAFeature else {
              return false
          }

          return rawValue == that.rawValue
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
