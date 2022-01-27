import XCTest
@testable
import AirshipCore

class ScopedSubscriptionListsTest: XCTestCase {

    func testObjcLists() throws {
        let subscriptionLists = ScopedSubscriptionLists(lists: ["some-list": [.email, .sms]])
        
        XCTAssertEqual(2, subscriptionLists.objc_lists["some-list"]?.count)
    }

}
