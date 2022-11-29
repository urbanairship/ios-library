/* Copyright Airship and Contributors */

import Foundation

protocol WorkBackgroundTimeProtocol {
    @MainActor
    var remainingTime: TimeInterval { get }
}

class WorkBackgroundTime: WorkBackgroundTimeProtocol {
    @MainActor
    var remainingTime: TimeInterval {
        #if os(watchOS)
        return Double.infinity
        #else
        return UIApplication.shared.backgroundTimeRemaining
        #endif
    }
}
