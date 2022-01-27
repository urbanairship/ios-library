import XCTest
@testable
import AirshipCore

class ScopedSubscriptionListsTest: XCTestCase {

    func testObjCLists() throws {
        let subscriptionLists = ScopedSubscriptionLists(["some-list": [.email, .sms]])
        XCTAssertEqual(2, subscriptionLists.objc_lists["some-list"]?.count)
    }

}
