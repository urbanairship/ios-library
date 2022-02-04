/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipPreferenceCenter
import AirshipCore

class PreferenceCenterConditionMonitorTest: XCTestCase {
        
    func testConditionMonitorCreatedChannel() {
        
        let expectation = expectation(description: "Waiting for the channel created event to the update preference center")
        
        let conditionMonitor = PreferenceCenterConditionMonitor {
            expectation.fulfill()
        }
        
        XCTAssertNotNil(conditionMonitor)
        
        NotificationCenter.default.post(name: Channel.channelCreatedEvent, object: nil)
        
        waitForExpectations(timeout: 1)
    }
    
    func testConditionMonitorChannelUpdated() {
        
        let expectation = expectation(description: "Waiting for the channel updated event to update the preference center")
        
        let conditionMonitor = PreferenceCenterConditionMonitor {
            expectation.fulfill()
        }

        XCTAssertNotNil(conditionMonitor)
        
        NotificationCenter.default.post(name: Channel.channelUpdatedEvent, object: nil)
        
        waitForExpectations(timeout: 1)
    }
}
