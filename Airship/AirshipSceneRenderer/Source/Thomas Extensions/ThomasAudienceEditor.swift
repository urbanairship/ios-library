/* Copyright Airship and Contributors */

import Foundation

/// Applies form-submission results to the audience: registers email/SMS channels and applies
/// channel/contact attributes. Host-provided so the renderer owns no contact/channel APIs.
/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public protocol ThomasAudienceEditor: Sendable {
    /// Registers channels (email/SMS) produced by a form submission.
    func registerChannels(_ channels: [ThomasChannelRegistration])

    /// Applies channel/contact attributes produced by a form submission.
    func applyAttributes(_ attributes: [ThomasAttribute])
}
