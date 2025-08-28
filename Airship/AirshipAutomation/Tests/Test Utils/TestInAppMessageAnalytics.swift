/* Copyright Airship and Contributors */


@testable import AirshipAutomation
@testable import AirshipCore

final class TestInAppMessageAnalytics: InAppMessageAnalyticsProtocol, @unchecked Sendable {

    var onMakeCustomEventContext: ((ThomasLayoutContext?) -> InAppCustomEventContext?)?
    func makeCustomEventContext(layoutContext: ThomasLayoutContext?) -> InAppCustomEventContext? {
        return onMakeCustomEventContext!(layoutContext)
    }
    
    var events: [(InAppEvent, ThomasLayoutContext?)] = []
    var impressionsRecored: UInt = 0
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        events.append((event, layoutContext))
    }
}
