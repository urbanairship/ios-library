/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasContext : ObservableObject {
    let eventHandler: ThomasEventHandler
    
    init(eventHandler: ThomasEventHandler) {
        self.eventHandler = eventHandler
    }
}
