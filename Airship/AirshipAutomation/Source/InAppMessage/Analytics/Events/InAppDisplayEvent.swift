/* Copyright Airship and Contributors */

import Foundation

struct InAppDisplayEvent: InAppEvent {
    let name: String = "in_app_display"
    let data: (Sendable&Encodable)? = nil
}
