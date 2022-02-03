/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

class ConditionStateMonitor {
    private let onChange: () -> Void
    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updatePreferenceCenter),
                                               name: Channel.channelCreatedEvent,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updatePreferenceCenter),
                                               name: Channel.channelUpdatedEvent,
                                               object: nil)
    }
    
    
    @objc
    func updatePreferenceCenter() {
        self.onChange()
    }
}
