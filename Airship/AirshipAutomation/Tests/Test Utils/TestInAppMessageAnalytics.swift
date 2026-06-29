/* Copyright Airship and Contributors */

import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

final class TestInAppMessageAnalytics: InAppMessageAnalyticsProtocol, @unchecked Sendable {

    var onMakeCustomEventContext: ((ThomasLayoutContext?) -> InAppCustomEventContext?)?
    func makeCustomEventContext(layoutContext: ThomasLayoutContext?) -> InAppCustomEventContext? {
        return onMakeCustomEventContext!(layoutContext)
    }
    
    var events: [(ThomasLayoutEvent, ThomasLayoutContext?)] = []
    var impressionsRecored: UInt = 0
    func recordEvent(_ event: ThomasLayoutEvent, layoutContext: ThomasLayoutContext?) {
        events.append((event, layoutContext))
    }
}
