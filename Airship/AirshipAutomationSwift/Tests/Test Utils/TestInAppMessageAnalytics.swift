/* Copyright Airship and Contributors */

import Foundation
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class TestInAppMessageAnalytics: InAppMessageAnalyticsProtocol, @unchecked Sendable {
    var events: [(InAppEvent, ThomasLayoutContext?)] = []
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        events.append((event, layoutContext))
    }
}
