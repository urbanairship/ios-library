/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Model object representing in-app message data.
 */
public struct LegacyInAppMessage: Sendable, Equatable {
    
    /**
     * Enumeration of in-app message screen positions.
     */
    public enum Position: String, Sendable {
        case top
        case bottom
    }
    
    /**
     * Enumeration of in-app message display types.
     */
    public enum DisplayType: String, Sendable {
        case banner
    }
    
    ///---------------------------------------------------------------------------------------
    /// @name Legacy In App Message Properties
    ///---------------------------------------------------------------------------------------
    
    /**
     * The unique identifier for the message
     */
    public let identifier: String
    
    ///---------------------------------------------------------------------------------------
    /// @name Legacy In App Message Top Level Properties
    ///---------------------------------------------------------------------------------------

    /**
     * The expiration date for the message.
     * Unless otherwise specified, defaults to 30 days from construction.
     */
    public let expiry: Date
    
    /**
     * Optional key value extra.
     */
    public let extra: AirshipJSON?
    
    ///---------------------------------------------------------------------------------------
    /// @name Legacy In App Message Display Properties
    ///---------------------------------------------------------------------------------------
    
    /**
     * The display type. Defaults to `LegacyInAppMessage.DisplayType.banner`
     * when built with the default class constructor.
     * When built from a payload with a missing or unidentified display type,
     * the message will be nil.
     */
    public let displayType: DisplayType
    
    /**
     * The alert message.
     */
    public let alert: String
    
    /**
     * The screen position. Defaults to `LegacyInAppMessage.Position.bottom`.
     */
    public let position: Position
    
    /**
     * The amount of time to wait before automatically dismissing
     * the message.
     */
    public let duration: TimeInterval
    
    /**
     * The primary color. hex
     */
    public let primaryColor: String?
    
    /**
     * The secondary color hex.
     */
    public let secondaryColor: String?
    
    ///---------------------------------------------------------------------------------------
    /// @name Legacy In App Message Actions Properties
    ///---------------------------------------------------------------------------------------

    /**
     * The button group (category) associated with the message.
     * This value will determine which buttons are present and their
     * localized titles.
     */
    public let buttonGroup: String?
    
    /**
     * A dictionary mapping button group keys to dictionaries
     * mapping action names to action arguments. The relevant
     * action(s) will be run when the user taps the associated
     * button.
     */
    public let buttonActions: [String: AirshipJSON]?
    
    /**
     * A dictionary mapping an action name to an action argument.
     * The relevant action will be run when the user taps or "clicks"
     * on the message.
     */
    public let onClick: AirshipJSON?
    
    let campaigns: AirshipJSON?
    let messageType: String?
    
    
    /*
     // Default values unless otherwise specified
             self.displayType = UALegacyInAppMessageDisplayTypeBanner;
             self.expiry = [NSDate dateWithTimeIntervalSinceNow:kUADefaultInAppMessageExpiryInterval];
             self.position = UALegacyInAppMessagePositionBottom;
             self.duration = kUADefaultInAppMessageDurationInterval;
     */
    
    /**
     * An array of UNNotificationAction instances corresponding to the left-to-right order
     * of interactive message buttons.
     */
    @MainActor
    var notificationActions: [UNNotificationAction]? {
        return self.buttonCategory?.actions
    }
    
    /**
     * A UNNotificationCategory instance,
     * corresponding to the button group of the message.
     * If no matching category is found, this property will be nil.
     */
    @MainActor
    public var buttonCategory: UNNotificationCategory? {
        guard let group = buttonGroup else { return nil }
        
        return Airship.push.combinedCategories.first(where: { $0.identifier == group })
    }
    
    init?(
        payload: [String: Any],
        overrideId: String? = nil,
        overrideOnClick: AirshipJSON? = nil,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        guard
            let identifier = overrideId ?? (payload[ParseKey.identifier.rawValue] as? String),
            let displayInfo = payload[ParseKey.display.rawValue] as? [String: Any],
            let displayTypeRaw = displayInfo[ParseKey.Display.type.rawValue] as? String,
            let displayType = DisplayType(rawValue: displayTypeRaw),
            let alert = displayInfo[ParseKey.Display.alert.rawValue] as? String
        else {
            return nil
        }
        
        
        let wrapJson: (Any?) -> AirshipJSON? = { input in
            guard let input = input else { return nil }
            
            do {
                return try AirshipJSON.wrap(input)
            } catch {
                AirshipLogger.warn("failed to wrap \(String(describing: input)), \(error)")
                return nil
            }
        }
        
        self.identifier = identifier
        self.campaigns = wrapJson(payload[ParseKey.campaigns.rawValue])
        self.messageType = payload[ParseKey.messageType.rawValue] as? String
        
        if 
            let rawDate = payload[ParseKey.expiry.rawValue] as? String,
            let date = AirshipDateFormatter.date(fromISOString: rawDate)
        {
            self.expiry = date
        } else {
            self.expiry = date.now.addingTimeInterval(Defaults.expiry)
        }
        
        self.extra = wrapJson(payload[ParseKey.extra.rawValue])
        self.displayType = displayType
        
        self.alert = alert
        self.duration = displayInfo[ParseKey.Display.duration.rawValue] as? Double ?? Defaults.duration
        
        if
            let positionRaw = displayInfo[ParseKey.Display.position.rawValue] as? String,
            let position = Position(rawValue: positionRaw) {
            self.position = position
        } else {
            self.position = .bottom
        }
        
        self.primaryColor = displayInfo[ParseKey.Display.primaryColor.rawValue] as? String
        self.secondaryColor = displayInfo[ParseKey.Display.secondaryColor.rawValue] as? String
        
        if let actionsInfo = payload[ParseKey.actions.rawValue] as? [String: Any] {
            self.buttonGroup = actionsInfo[ParseKey.Action.buttonGroup.rawValue] as? String
            if let actions = actionsInfo[ParseKey.Action.buttonActions.rawValue] as? [String: Any] {
                self.buttonActions = actions.reduce(into: [String: AirshipJSON]()) { partialResult, record in
                    if let json = wrapJson(record.value) {
                        partialResult[record.key] = json
                    }
                }
            } else {
                self.buttonActions = nil
            }
            self.onClick = overrideOnClick ?? wrapJson(actionsInfo[ParseKey.Action.onClick.rawValue])
        } else {
            self.buttonGroup = nil
            self.buttonActions = nil
            self.onClick = overrideOnClick
        }
    }

    private enum ParseKey: String {
        case identifier = "identifier"
        case campaigns = "campaigns"
        case messageType = "message_type"
        case expiry = "expiry"
        case extra = "extra"
        case display = "display"
        case actions = "actions"
        
        enum Action: String {
            case buttonGroup = "button_group"
            case buttonActions = "button_actions"
            case onClick = "on_click"
        }
        
        enum Display: String {
            case type = "type"
            case position = "position"
            case alert = "alert"
            case duration = "duration"
            case primaryColor = "primary_color"
            case secondaryColor = "secondary_color"
        }
    }
    
    private enum Defaults {
        static let expiry: TimeInterval = 60 * 60 * 24 * 30 // 30 days in seconds
        static let duration: TimeInterval = 15 // seconds
    }
}
