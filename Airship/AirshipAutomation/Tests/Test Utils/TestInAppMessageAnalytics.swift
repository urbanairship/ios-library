/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipAutomation
@testable import AirshipCore

final class TestInAppMessageAnalytics: InAppMessageAnalyticsProtocol, @unchecked Sendable {
    var events: [(InAppEvent, ThomasLayoutContext?)] = []
    var impressionsRecored: UInt = 0
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        events.append((event, layoutContext))
    }
    
    func recordImpression() {
        impressionsRecored += 1
    }
}
