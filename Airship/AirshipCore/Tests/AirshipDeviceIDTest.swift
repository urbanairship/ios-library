/* Copyright Airship and Contributors */

import Testing

@testable
@_spi(AirshipInternal) import AirshipCore
import Foundation

@Suite struct AirshipDeviceIDTest {

    private let appKey: String = UUID().uuidString
    private let keychain: TestKeyChainAccess = TestKeyChainAccess()
    private let deviceID: AirshipDeviceID

    init() {
        self.deviceID = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
    }

    @Test
    func testGenerateDeviceID() async {
        let id = await deviceID.value
        let fromStore = await self.keychain.readCredentails(identifier: "com.urbanairship.deviceID", appKey: appKey)
        #expect(fromStore?.password == id)
    }

    @Test
    func testRestoreFromKeychain() async {
        let first = await deviceID.value

        let restored = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
        let second = await restored.value

        #expect(first == second)
    }
}
