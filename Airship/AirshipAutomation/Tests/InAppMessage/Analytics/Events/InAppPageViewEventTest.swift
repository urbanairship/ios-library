/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class InAppPageViewEventTest: XCTestCase {

    func testEvent() throws {
        let event = InAppPageViewEvent(
            pagerInfo: ThomasPagerInfo(
                identifier: "pager identifier",
                pageIndex: 3,
                pageIdentifier: "page identifier",
                pageCount: 12,
                completed: false
            ),
            viewCount: 31
        )

        let expectedJSON = """
        {
           "page_identifier":"page identifier",
           "page_index":3,
           "viewed_count":31,
           "page_count":12,
           "pager_identifier":"pager identifier",
           "completed":false
        }
        """

        XCTAssertEqual(event.name, "in_app_page_view")
        XCTAssertEqual(try event.bodyJSON, try! AirshipJSON.from(json: expectedJSON))
    }

}
