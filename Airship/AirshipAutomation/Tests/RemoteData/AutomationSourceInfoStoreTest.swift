/* Copyright Airship and Contributors */

import Testing
import Foundation

import AirshipCore
@testable @_spi(AirshipInternal)
import AirshipAutomation

struct AutomationSourceInfoStoreTest {

    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let infoStore: AutomationSourceInfoStore

    init() {
        self.infoStore = AutomationSourceInfoStore(dataStore: dataStore)
    }

    @Test
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

        #expect(expected == actual)
    }

    @Test
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

        #expect(expected == actual)
    }

    @Test
    func testAppStoreIgnoreContactID() throws {
        let sourceInfo = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: Date(),
            airshipSDKVersion: "17.9.9",
            failedSchedules: []
        )
        self.infoStore.setSourceInfo(sourceInfo, source: .app, contactID: "foo")

        #expect(
            sourceInfo ==
            self.infoStore.getSourceInfo(source: .app, contactID: nil)
        )

        #expect(
            sourceInfo ==
            self.infoStore.getSourceInfo(source: .app, contactID: "foo")
        )

        #expect(
            sourceInfo ==
            self.infoStore.getSourceInfo(source: .app, contactID: UUID().uuidString)
        )
    }

    @Test
    func testContactStoreRespectsContactID() throws {
        let sourceInfo = AutomationSourceInfo(
            remoteDataInfo: nil,
            payloadTimestamp: Date(),
            airshipSDKVersion: "17.9.9",
            failedSchedules: []
        )
        self.infoStore.setSourceInfo(sourceInfo, source: .contact, contactID: "foo")

        #expect(
            self.infoStore.getSourceInfo(source: .contact, contactID: nil) == nil
        )

        #expect(
            self.infoStore.getSourceInfo(source: .contact, contactID: UUID().uuidString) == nil
        )

        #expect(
            sourceInfo ==
            self.infoStore.getSourceInfo(source: .contact, contactID: "foo")
        )
    }

}
