/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class AirshipDeviceIDTest: XCTestCase {

    private let appKey: String = UUID().uuidString
    private let keychain: TestKeyChainAccess = TestKeyChainAccess()
    private var deviceID: AirshipDeviceID!

    override func setUp() async throws {
        self.deviceID = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
    }

    func testGenerateDeviceID() async {
        let id = await deviceID.value
        XCTAssertNotNil(id)
        let fromStore = await self.keychain.readCredentails(identifier: "com.urbanairship.deviceID", appKey: appKey)
        XCTAssertEqual(fromStore?.password, id)
    }

    func testRestoreFromKeychain() async {
        let first = await deviceID.value
        XCTAssertNotNil(first)

        self.deviceID = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
        let second = await deviceID.value

        XCTAssertEqual(first, second)
    }
}
