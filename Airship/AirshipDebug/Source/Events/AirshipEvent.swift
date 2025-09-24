/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

struct AirshipEvent: Equatable, Hashable, Sendable {
    /// The unique identifier of the event.
    var identifier: String
    
    /// The type of the event (e.g., "custom_event", "app_foreground").
    var type: String
    
    /// The date and time when the event occurred.
    var date: Date
    
    /// The JSON body of the event as a formatted string.
    var body: String
}
