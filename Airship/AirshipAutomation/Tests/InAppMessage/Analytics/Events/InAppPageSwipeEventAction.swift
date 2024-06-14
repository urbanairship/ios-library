/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipAutomation
@testable import AirshipCore

final class InAppPageSwipeEventAction: XCTestCase {

    func testEvent() throws {
        let event = InAppPageSwipeEvent(
            from: ThomasPagerInfo(
                identifier: "pager identifier",
                pageIndex: 3,
                pageIdentifier: "from page identifier",
                pageCount: 12,
                completed: false
            ),
            to: ThomasPagerInfo(
                identifier: "pager identifier",
                pageIndex: 4,
                pageIdentifier: "to page identifier",
                pageCount: 12,
                completed: false
            )
        )

        let expectedJSON = """
        {
           "pager_identifier":"pager identifier",
           "from_page_index":3,
           "to_page_identifier":"to page identifier",
           "from_page_identifier":"from page identifier",
           "to_page_index":4
        }
        """

        XCTAssertEqual(event.name.reportingName, "in_app_page_swipe")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
