/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Button info
public struct InAppMessageButtonInfo: Sendable, Codable, Equatable {
    /// Button behavior
    public enum Behavior: String, Sendable, Codable {
        /// Dismisses the message when tapped
        case dismiss

        /// Dismisses and cancels the message when tapped
        case cancel
    }

    /// Button identifier, used for reporting
    public let identifier: String

    /// Button label
    public var label: InAppMessageTextInfo

    /// Button actions
    public var actions: AirshipJSON?

    /// Button behavior
    public var behavior: Behavior?

    // Background color
    public var backgroundColor: InAppMessageColor?

    /// Border color
    public var borderColor: InAppMessageColor?

    /// Border radius in points
    public var borderRadius: Double?

    /// In-app message button model
    /// - Parameters:
    ///   - identifier: Button identifier
    ///   - label: Text model for the button text
    ///   - actions: Actions for the button to execute
    ///   - behavior: Behavior of the button on tap
    ///   - backgroundColor: Background color
    ///   - borderColor: Border color
    ///   - borderRadius: Border radius
    public init(
        identifier: String,
        label: InAppMessageTextInfo,
        actions: AirshipJSON? = nil,
        behavior: Behavior? = nil,
        backgroundColor: InAppMessageColor? = nil,
        borderColor: InAppMessageColor? = nil,
        borderRadius: Double? = nil
    ) {
        self.identifier = identifier
        self.label = label
        self.actions = actions
        self.behavior = behavior
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderRadius = borderRadius
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case label
        case actions
        case behavior
        case backgroundColor = "background_color"
        case borderColor = "border_color"
        case borderRadius = "border_radius"
    }
}
