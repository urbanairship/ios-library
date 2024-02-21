/* Copyright Airship and Contributors */

import Foundation

struct AirshipEvents {
    static func deviceRegistrationEvent(
        channelID: String?,
        deviceToken: String
    ) -> AirshipEvent {
        return AirshipEvent(
            priority: .normal,
            eventType: "device_registration",
            eventData: AirshipJSON.makeObject { object in
                object.set(string: channelID, key: "channel_id")
                object.set(string: deviceToken, key: "device_token")
            }
        )
    }

    static func pushReceivedEvent(
        notification: [AnyHashable: Any]
    ) -> AirshipEvent {
        let metadata = notification["com.urbanairship.metadata"] as? String
        let pushID = notification["_"] as? String

        return AirshipEvent(
            priority: .normal,
            eventType: "push_received",
            eventData: AirshipJSON.makeObject { object in
                object.set(string: metadata, key: "metadata")
                object.set(string: pushID ?? "MISSING_SEND_ID", key: "push_id")
            }
        )
    }

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
            eventType: "interactive_notification_action",
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
        let endTime = startDate.addingTimeInterval(duration).timeIntervalSince1970

        return AirshipEvent(
            priority: .normal,
            eventType: "screen_tracking",
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
            eventType: "associate_identifiers",
            eventData: try AirshipJSON.wrap(identifiers)
        )
    }

    static func installAttirbutionEvent(
        appPurchaseDate: Date? = nil,
        iAdImpressionDate: Date? = nil
    ) -> AirshipEvent {
        return AirshipEvent(
            priority: .normal,
            eventType: "install_attribution",
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
        push: AirshipPushProtocol
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

    var eventType: String {
        switch self.type {
        case .foregroundInit, .backgroundInit: return "app_init"
        case .background: return "app_background"
        case .foreground: return "app_foreground"
        }
    }

    @MainActor
    func eventData(
        push: AirshipPushProtocol
    ) -> AirshipJSON {
        return AirshipJSON.makeObject { object in
            /// Common
            object.set(string: sessionState.conversionSendID, key: "push_id")
            object.set(string: sessionState.conversionMetadata, key: "metadata")

#if !os(watchOS)
            object.set(string: AirshipUtils.connectionType(), key: "connection_type")
#endif

            /// App init
            if self.isAppInit {
                let isForeground = self.type == .foregroundInit
                object.set(string: isForeground.toString(), key: "foreground")
            }


            /// App init or foreground
            if self.isAppInit || self.type == .foreground {
                object.set(string: AirshipUtils.carrierName(), key: "carrier")
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

    private static var osVersion: String {
#if !os(watchOS)
        return UIDevice.current.systemVersion
#else
       return WKInterfaceDevice.current().systemVersion
#endif
    }
}
