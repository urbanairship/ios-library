/* Copyright Airship and Contributors */

import SwiftUI
import Foundation
public import AirshipBasement

/// - Note: For internal use only. :nodoc:
public struct AirshipEmbeddedInfo: Equatable, Hashable, Sendable {

    /// A generated instance ID.
    public let instanceID: String

    /// Embedded ID. This is the ID used to place the embedded view.
    public let embeddedID: String

    /// The message extras
    public let extras: AirshipJSON?

    /// View priority. Lower is higher priority.
    public let priority: Int

    /// What this content is about, from the layout's `content_description`. Nil when the
    /// layout doesn't describe itself.
    public let contentDescription: String?

    /// Layout-authored user context, from `content_description.additional_context`. Empty
    /// when the layout provides none.
    ///
    /// Pooled across the pending candidates and merged with the app provider's context for
    /// AI selection, so these are facts about the *user*, not about this instance —
    /// ``contentDescription`` is what describes the instance.
    ///
    /// Internal rather than public: it exists to feed the on-device model, not to be read
    /// by apps.
    /// - Note: For internal use only. :nodoc:
    @_spi(AirshipInternal)
    public let additionalContext: [ThomasAIContextItem]

    @_spi(AirshipInternal)
    public init(
        instanceID: String,
        embeddedID: String,
        extras: AirshipJSON?,
        priority: Int,
        contentDescription: String? = nil,
        additionalContext: [ThomasAIContextItem] = []
    ) {
        self.instanceID = instanceID
        self.embeddedID = embeddedID
        self.extras = extras
        self.priority = priority
        self.contentDescription = contentDescription
        self.additionalContext = additionalContext
    }
}
