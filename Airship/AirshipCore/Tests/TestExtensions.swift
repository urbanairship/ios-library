/* Copyright Airship and Contributors */

import XCTest
import Foundation

extension XCTestCase {
    func fulfillmentCompat(of: [XCTestExpectation], timeout: TimeInterval? = nil) async {
        wait(for: of, timeout: timeout ?? 10.0)
    }
}
