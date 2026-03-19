/* Copyright Airship and Contributors */

import Foundation

/// Errors that can occur when loading Message Center messages.
public enum MessageCenterMessageError: Error {

    /// No message exists in the inbox for the provided message ID.
    case messageGone

    /// A network failure occurred while fetching the message or inbox data.
    case failedToFetchMessage
}
