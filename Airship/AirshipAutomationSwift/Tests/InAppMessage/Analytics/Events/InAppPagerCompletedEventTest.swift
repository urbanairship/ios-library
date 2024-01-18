/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomationSwift
import AirshipCore

final class InAppPagerCompletedEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppPagerCompletedEvent(
            pagerInfo: ThomasPagerInfo(
                identifier: "pager identifier",
                pageIndex: 3,
                pageIdentifier: "page identifier",
                pageCount: 12,
                completed: true
            )
        )

        let expectedJSON = """
        {
           "page_count":12,
           "pager_identifier":"pager identifier",
           "page_index":3,
           "page_identifier":"page identifier"
        }
        """

        XCTAssertEqual(event.name, "in_app_pager_completed")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }
}
