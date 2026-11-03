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
        guard case .success(let credentials) = fromStore else {
            Issue.record("Expected stored device ID")
            return
        }
        #expect(credentials.password == id)
        #expect(id != AirshipDeviceID.unknownValue)
    }

    @Test
    func testRestoreFromKeychain() async {
        let first = await deviceID.value

        let restored = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
        let second = await restored.value

        #expect(first == second)
    }

    @Test
    func testReadErrorReturnsUnknownWithoutMinting() async {
        let first = await deviceID.value

        keychain.readError = errSecMissingEntitlement
        let failing = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
        let result = await failing.value

        #expect(result == AirshipDeviceID.unknownValue)

        // The original item must still be present and must not have been
        // overwritten by a mint.
        keychain.readError = nil
        let afterError = await keychain.readCredentails(
            identifier: "com.urbanairship.deviceID",
            appKey: appKey
        )
        guard case .success(let credentials) = afterError else {
            Issue.record("Expected original device ID to remain stored")
            return
        }
        #expect(credentials.password == first)

        let recovered = AirshipDeviceID(appKey: self.appKey, keychain: keychain)
        #expect(await recovered.value == first)
    }

    @Test
    func testReadErrorIsNotCached() async {
        keychain.readError = errSecMissingEntitlement
        #expect(await deviceID.value == AirshipDeviceID.unknownValue)

        keychain.readError = nil
        let minted = await deviceID.value
        #expect(minted != AirshipDeviceID.unknownValue)

        guard case .success(let credentials) = await keychain.readCredentails(
            identifier: "com.urbanairship.deviceID",
            appKey: appKey
        ) else {
            Issue.record("Expected device ID to be persisted after recovery")
            return
        }
        #expect(credentials.password == minted)
    }

    @Test
    func testWriteFailureReturnsUnknownWithoutCaching() async {
        keychain.writeSucceeds = false
        #expect(await deviceID.value == AirshipDeviceID.unknownValue)

        guard case .itemNotFound = await keychain.readCredentails(
            identifier: "com.urbanairship.deviceID",
            appKey: appKey
        ) else {
            Issue.record("Failed write must not persist a device ID")
            return
        }

        keychain.writeSucceeds = true
        let minted = await deviceID.value
        #expect(minted != AirshipDeviceID.unknownValue)

        guard case .success(let credentials) = await keychain.readCredentails(
            identifier: "com.urbanairship.deviceID",
            appKey: appKey
        ) else {
            Issue.record("Expected device ID to be persisted after write succeeds")
            return
        }
        #expect(credentials.password == minted)
    }
}
