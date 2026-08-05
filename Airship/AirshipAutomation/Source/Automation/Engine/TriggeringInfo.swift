/* Copyright Airship and Contributors */

import Foundation

@_spi(AirshipInternal) import AirshipCore

struct TriggeringInfo: Equatable, Sendable, Codable {
    var context: AirshipTriggerContext?
    var date: Date

    /// ID of the trigger that caused this. Carried through prepare/execute so
    /// ledger events can attribute themselves to a trigger. Optional for
    /// backward compatibility with persisted data recorded before it existed.
    var triggerID: String?

    init(context: AirshipTriggerContext? = nil, date: Date, triggerID: String? = nil) {
        self.context = context
        self.date = date
        self.triggerID = triggerID
    }
}
