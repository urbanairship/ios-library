/* Copyright Airship and Contributors */

import Foundation

/// Errors that can occur when loading Message Center messages.
public enum MessageCenterMessageError: Error, Sendable, Equatable {

    /// No message exists in the inbox for the provided message ID.
    case messageGone

    /// A network failure occurred while fetching the message or inbox data.
    case failedToFetchMessage

    /// The message was fetched but its content (web body or native layout)
    /// failed to load.
    case messageLoadFailed
}

extension MessageCenterMessageError {
    /// Maps an arbitrary error to a ``MessageCenterMessageError``, preserving an
    /// existing ``MessageCenterMessageError`` value and otherwise reporting
    /// ``messageLoadFailed``.
    static func from(_ error: any Error) -> MessageCenterMessageError {
        error as? MessageCenterMessageError ?? .messageLoadFailed
    }
}
