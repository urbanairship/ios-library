/* Copyright Airship and Contributors */

public import AirshipCore

/// The feature-specific context subject for in-app message AI filtering.
///
/// Passed to the app's registered `ContextProvider<InAppMessageFilterContext>` so it
/// can return user context that is relevant to the specific message being considered.
public struct InAppMessageFilterContext: Sendable {
    /// Message name.
    public let name: String

    /// Flat string extras from the message.
    public let extras: AirshipJSON?

    /// Campaign metadata from the enclosing automation schedule, if any.
    public let campaigns: AirshipJSON?

    public init(
        name: String,
        extras: AirshipJSON? = nil,
        campaigns: AirshipJSON? = nil
    ) {
        self.name = name
        self.extras = extras
        self.campaigns = campaigns
    }

    /// The AI usage key for in-app message filtering.
    ///
    /// Pass this to `Airship.ai.setProvider(_:for:)` when registering a context provider
    /// for in-app message relevance filtering.
    public static let filterUsage = AirshipAI.Usage<InAppMessageFilterContext>(
        rawValue: "in_app_message_filter"
    )
}
