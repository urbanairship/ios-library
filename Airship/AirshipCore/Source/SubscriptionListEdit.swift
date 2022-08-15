/* Copyright Airship and Contributors */

import Foundation

/// Represents an edit made to a subsription list through the SDK.
public enum SubscriptionListEdit: Equatable {
    /// Subscribed
    case subscribe(String)

    /// Unsubscribed
    case unsubscribe(String)
}

