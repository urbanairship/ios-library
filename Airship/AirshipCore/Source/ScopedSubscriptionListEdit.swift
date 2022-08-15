/* Copyright Airship and Contributors */

import Foundation

/// Represents an edit made to a scoped subsription list through the SDK.
public enum ScopedSubscriptionListEdit: Equatable {

    /// Subscribed
    case subscribe(String, ChannelScope)

    /// Unsubscribed
    case unsubscribe(String, ChannelScope)
}
