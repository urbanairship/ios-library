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

    /// The message's content type can't be displayed on this device, e.g. web
    /// content on a platform without WebKit. Retrying won't succeed.
    case unsupportedOnDevice
}

extension MessageCenterMessageError {
    /// The localization key for the message shown when no retry is offered.
    var localizedDescriptionKey: String {
        switch self {
        case .messageGone: "ua_mc_no_longer_available"
        case .unsupportedOnDevice: "ua_mc_unsupported_on_device"
        case .failedToFetchMessage, .messageLoadFailed: "ua_mc_failed_to_load"
        }
    }

    /// Maps an arbitrary error to a ``MessageCenterMessageError``, preserving an
    /// existing ``MessageCenterMessageError`` value and otherwise reporting
    /// ``messageLoadFailed``.
    static func from(_ error: any Error) -> MessageCenterMessageError {
        error as? MessageCenterMessageError ?? .messageLoadFailed
    }
}
