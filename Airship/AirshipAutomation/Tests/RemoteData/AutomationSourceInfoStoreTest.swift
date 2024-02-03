/* Copyright Airship and Contributors */

import XCTest

import AirshipCore
@testable
import AirshipAutomation

final class AutomationSourceInfoStoreTest: XCTestCase {

    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private var infoStore: AutomationSourceInfoStore!

    override func setUp() async throws {
        self.infoStore = AutomationSourceInfoStore(dataStore: dataStore)
    }

    func testMigrateChannel() throws {
        let lastPayloadTimestamp = Date() - 1000.0
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url://")!,
            lastModifiedTime: UUID().uuidString,
            source: .app
        )

        dataStore.setObject(lastPayloadTimestamp, forKey: "UAInAppRemoteDataClient.LastPayloadTimeStamp")
        dataStore.setObject("17.9.9", forKey: "UAInAppRemoteDataClient.LastSDKVersion")
        dataStore.setSafeCodable(remoteDataInfo, forKey: "UAInAppRemoteDataClient.LastRemoteDataInfo")
        dataStore.setSafeCodable(remoteDataInfo, forKey: "UAInAppRemoteDataClient.LastPayloadMetadata")

        let expected = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: lastPayloadTimestamp,
            airshipSDKVersion: "17.9.9"
        )

        let actual = self.infoStore.getSourceInfo(source: .app, contactID: nil)

        XCTAssertEqual(expected, actual)
    }

    func testMigrateContact() throws {
        let lastPayloadTimestamp = Date() - 1000.0
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url://")!,
            lastModifiedTime: UUID().uuidString,
            source: .contact
        )

        dataStore.setObject(lastPayloadTimestamp, forKey: "UAInAppRemoteDataClient.LastPayloadTimeStamp.Contactfoo")
        dataStore.setObject("17.9.9", forKey: "UAInAppRemoteDataClient.LastSDKVersion.Contactfoo")
        dataStore.setSafeCodable(remoteDataInfo, forKey: "UAInAppRemoteDataClient.LastRemoteDataInfo.Contactfoo")
        dataStore.setSafeCodable(remoteDataInfo, forKey: "UAInAppRemoteDataClient.LastPayloadMetadata.Contactfoo")

        let expected = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: lastPayloadTimestamp,
            airshipSDKVersion: "17.9.9"
        )

        let actual = self.infoStore.getSourceInfo(source: .contact, contactID: "foo")

        XCTAssertEqual(expected, actual)
    }

    func testAppStoreIgnoreContactID() throws {
        let sourceInfo = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: Date(),
            airshipSDKVersion: "17.9.9"
        )
        self.infoStore.setSourceInfo(sourceInfo, source: .app, contactID: "foo")

        XCTAssertEqual(
            sourceInfo,
            self.infoStore.getSourceInfo(source: .app, contactID: nil)
        )

        XCTAssertEqual(
            sourceInfo,
            self.infoStore.getSourceInfo(source: .app, contactID: "foo")
        )

        XCTAssertEqual(
            sourceInfo,
            self.infoStore.getSourceInfo(source: .app, contactID: UUID().uuidString)
        )
    }

    func testContactStoreRespectsContactID() throws {
        let sourceInfo = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: Date(),
            airshipSDKVersion: "17.9.9"
        )
        self.infoStore.setSourceInfo(sourceInfo, source: .contact, contactID: "foo")

        XCTAssertNil(
            self.infoStore.getSourceInfo(source: .contact, contactID: nil)
        )

        XCTAssertNil(
            self.infoStore.getSourceInfo(source: .contact, contactID: UUID().uuidString)
        )

        XCTAssertEqual(
            sourceInfo,
            self.infoStore.getSourceInfo(source: .contact, contactID: "foo")
        )
    }

}
