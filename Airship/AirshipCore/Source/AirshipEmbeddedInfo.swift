/* Copyright Airship and Contributors */

import SwiftUI


/// NOTE: For internal use only. :nodoc:
public struct AirshipEmbeddedInfo: Equatable, Hashable, Sendable {

    /// A generated instance ID.
    public let instanceID: String

    /// Embedded ID. This is the ID used to place the embedded view.
    public let embeddedID: String

    /// The message extras
    public let extras: AirshipJSON?

    /// View priority. Lower is higher priority.
    public let priority: Int

    init(instanceID: String, embeddedID: String, extras: AirshipJSON?, priority: Int) {
        self.instanceID = instanceID
        self.embeddedID = embeddedID
        self.extras = extras
        self.priority = priority
    }
}
