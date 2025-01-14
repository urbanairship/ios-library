///* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

public let testExpectationTimeOut = 10.0

class AirshipBaseTest: XCTestCase {
    
    /**
     * A preference data store unique to this test. The dataStore is created
     * lazily when first used.
     */
    lazy var dataStore: PreferenceDataStore = {
        return PreferenceDataStore(appKey: UUID().uuidString)
    }()
    
    /**
     * A preference airship with unique appkey/secret. A runtime config is created
     * lazily when first used.
     */
    lazy var config: RuntimeConfig = RuntimeConfig.testConfig()    
}

