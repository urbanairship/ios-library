/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct AirshipEvents {
    
#if !os(tvOS)
    static func interactiveNotificationEvent(
        action: UNNotificationAction,
        category: String,
        notification: [AnyHashable: Any],
        responseText: String?
    ) -> AirshipEvent {
        let pushID = notification["_"] as? String

        return AirshipEvent(
            priority: .high,
            eventType: .interactiveNotificationAction,
            eventData: AirshipJSON.makeObject { object in
                object.set(string: category, key: "button_group")
                object.set(string: action.identifier, key: "button_id")
                object.set(string: action.title, key: "button_description")
                object.set(string: action.isForeground.toString(), key: "foreground")
                object.set(string: pushID, key: "send_id")
                object.set(string: responseText?.truncate(maxCount: 255), key: "user_input")
            }
        )
    }
#endif

    static func screenTrackingEvent(
        screen: String,
        previousScreen: String?,
        startDate: Date,
        duration: TimeInterval
    ) throws -> AirshipEvent {
        guard duration > 0 else {
            throw AirshipErrors.error("Invalid screen event \(screen), duration is zero.")
        }

        guard screen.count >= 1, screen.count <= 255  else {
            throw AirshipErrors.error("Invalid screen name \(screen), Must be between 1 and 255 characters.")
        }

        let startTime = startDate.timeIntervalSince1970
        let endTime = startDate.advanced(by: duration).timeIntervalSince1970

        return AirshipEvent(
            priority: .normal,
            eventType: .screenTracking,
            eventData: AirshipJSON.makeObject { object in
                object.set(string: screen, key: "screen")
                object.set(string: previousScreen, key: "previous_screen")
                object.set(string: startTime.toString(), key: "entered_time")
                object.set(string: endTime.toString(), key: "exited_time")
                object.set(string: duration.toString(), key: "duration")
            }
        )
    }

    static func associatedIdentifiersEvent(
        identifiers: AssociatedIdentifiers?
    ) throws -> AirshipEvent {
        let identifiers = identifiers?.allIDs ?? [:]
        guard identifiers.count <= AssociatedIdentifiers.maxCount else {
            throw AirshipErrors.error(
                "Associated identifiers count exceed \(AssociatedIdentifiers.maxCount)"
            )
        }

        try identifiers.forEach {
            if $0.key.count > AssociatedIdentifiers.maxCharacterCount {
                throw AirshipErrors.error(
                    "Associated identifier \($0) key exceeds \(AssociatedIdentifiers.maxCharacterCount) characters"
                )
            }

            if $0.value.count > AssociatedIdentifiers.maxCharacterCount {
                throw AirshipErrors.error(
                    "Associated identifier \($0) value exceeds \(AssociatedIdentifiers.maxCharacterCount) characters"
                )
            }
        }

        return AirshipEvent(
            priority: .normal,
            eventType: .associateIdentifiers,
            eventData: try AirshipJSON.wrap(identifiers)
        )
    }

    static func installAttirbutionEvent(
        appPurchaseDate: Date? = nil,
        iAdImpressionDate: Date? = nil
    ) -> AirshipEvent {
        return AirshipEvent(
            priority: .normal,
            eventType: .installAttribution,
            eventData: AirshipJSON.makeObject { object in
                object.set(
                    string: appPurchaseDate?.timeIntervalSince1970.toString(),
                    key: "app_store_purchase_date"
                )
                object.set(
                    string: iAdImpressionDate?.timeIntervalSince1970.toString(),
                    key: "app_store_ad_impression_date"
                )
            }
        )
    }

    @MainActor
    static func sessionEvent(
        sessionEvent: SessionEvent,
        push: any AirshipPush
    ) -> AirshipEvent {
        return AirshipEvent(
            priority: .normal,
            eventType: sessionEvent.eventType,
            eventData: sessionEvent.eventData(push: push)
        )
    }
}

fileprivate extension TimeInterval {
    func toString() -> String {
        String(
            format: "%0.3f",
            self
        )
    }
}

fileprivate extension Bool {
    func toString() -> String {
        return self ? "true" : "false"
    }
}

#if !os(tvOS)
fileprivate extension UNNotificationAction {
    var isForeground: Bool {
        return (self.options.rawValue & UNNotificationActionOptions.foreground.rawValue) > 0
    }
}
#endif

fileprivate extension String {
    func truncate(maxCount: Int) -> String {
        return if self.count > maxCount {
            String(self.prefix(maxCount))
        } else {
           self
        }
    }
}

fileprivate extension SessionEvent {
    var isAppInit: Bool {
        switch self.type {
        case .foregroundInit, .backgroundInit: return true
        case .background, .foreground: return false
        }
    }

    var eventType: EventType {
        switch self.type {
        case .foregroundInit, .backgroundInit: return .appInit
        case .background: return .appBackground
        case .foreground: return .appForeground
        }
    }

    @MainActor
    func eventData(
        push: any AirshipPush
    ) -> AirshipJSON {
        return AirshipJSON.makeObject { object in
            /// Common
            object.set(string: sessionState.conversionSendID, key: "push_id")
            object.set(string: sessionState.conversionMetadata, key: "metadata")

            /// App init
            if self.isAppInit {
                let isForeground = self.type == .foregroundInit
                object.set(string: isForeground.toString(), key: "foreground")
            }


            /// App init or foreground
            if self.isAppInit || self.type == .foreground {
                object.set(string: AirshipVersion.version, key: "lib_version")
                object.set(string: AirshipUtils.bundleShortVersionString() ?? "", key: "package_version")

                object.set(string: Self.osVersion, key:"os_version")


                let localtz = TimeZone.current
                object.set(double: Double(localtz.secondsFromGMT()), key:"time_zone")
                object.set(string: localtz.isDaylightSavingTime().toString(), key: "daylight_savings")

                let notificationTypes = EventUtils.notificationTypes(
                    authorizedSettings: push.authorizedNotificationSettings
                )?.map { AirshipJSON.string($0) }

                let authroizedStatus = EventUtils.notificationAuthorization(
                    authorizationStatus: push.authorizationStatus
                )

                object.set(array: notificationTypes, key: "notification_types")
                object.set(string: authroizedStatus, key: "notification_authorization")
            }
        }
    }

    @MainActor
    private static var osVersion: String {
#if !os(watchOS)
        return UIDevice.current.systemVersion
#else
       return WKInterfaceDevice.current().systemVersion
#endif
    }
}
