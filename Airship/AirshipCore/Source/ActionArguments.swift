/* Copyright Airship and Contributors */

import Foundation

/// Action situations
@objc(UAActionSituation)
public enum ActionSituation: Int, Sendable {
    /// Action invoked manually
    case manualInvocation
    /// Action invoked from the app being launched from a push notification
    case launchedFromPush
    /// Action invoked from a foreground push
    case foregroundPush
    /// Action invoked from a background push
    case backgroundPush
    /// Action invoked from a web view
    case webViewInvocation
    /// Action invoked from a foreground action button
    case foregroundInteractiveButton
    /// Action invoked from a background action button
    case backgroundInteractiveButton
    /// Action invoked from an automation
    case automation
}

/// Contains the arguments passed into an action during execution.
public struct ActionArguments: Sendable {

    /// Metadata key for the user notification action identifier. Available when an action is triggered from a
    /// user notification action. The ID will be a String.
    public static let userNotificationActionIDMetadataKey: String = "com.urbanairship.user_notification_action_id"

    /// Metadata key for the push notification. Available when an action is triggered
    /// from a push notification or user notification action. The payload will be an `AirshipJSON`.
    public static let pushPayloadJSONMetadataKey: String = "com.urbanairship.payload"
    public static let isForegroundPresentationMetadataKey: String = "com.urbanairship.is_foreground_presentation"

    /// Metadata key for the inbox message's identifier. Available when an action is triggered from an
    /// inbox message. The ID will be a String.
    public static let inboxMessageIDMetadataKey: String = "com.urbanairship.messageID"


    /// Metadata key for the user notification action response info text. Available when an action is triggered
    /// from a user notification action with the behavior `UIUserNotificationActionBehaviorTextInput`.
    public static let responseInfoMetadataKey: String = "com.urbanairship.response_info"

    /// The action argument's value
    public let value: AirshipJSON

    /// The action argument's situation
    public let situation: ActionSituation

    /// The action argument's metadata
    public let metadata: [String: Sendable]

    public init(
        string: String,
        situation: ActionSituation = .manualInvocation,
        metadata: [String : Sendable] = [:]
    ) {
        self.value = AirshipJSON.string(string)
        self.situation = situation
        self.metadata = metadata
    }

    public init(
        double: Double,
        situation: ActionSituation = .manualInvocation,
        metadata: [String : Sendable] = [:]
    ) {
        self.value = AirshipJSON.number(double)
        self.situation = situation
        self.metadata = metadata
    }

    public init(
        bool: Bool,
        situation: ActionSituation = .manualInvocation,
        metadata: [String : Sendable] = [:]
    ) {
        self.value = AirshipJSON.bool(bool)
        self.situation = situation
        self.metadata = metadata
    }

    public init(
        value: AirshipJSON = AirshipJSON.null,
        situation: ActionSituation = .manualInvocation,
        metadata: [String : Sendable] = [:]
    ) {
        self.value = value
        self.situation = situation
        self.metadata = metadata
    }
}
