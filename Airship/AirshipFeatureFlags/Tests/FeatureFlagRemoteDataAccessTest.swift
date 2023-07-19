/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class FeatureFlagRemoteDataAccessTest: XCTestCase {

    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let remoteData: TestRemoteData = TestRemoteData()

    private var remoteDataAccess: FeatureFlagRemoteDataAccess!

    override func setUp() {
        self.remoteDataAccess = FeatureFlagRemoteDataAccess(
            remoteData: self.remoteData,
            networkChecker: self.networkChecker
        )
    }

    func testRefreshAlreadyUpToDate() async throws {
        await self.networkChecker.setConnected(true)
        self.remoteData.status[.app] = .stale
        self.remoteData.refreshBlock = { source in
            XCTAssertEqual(source, .app)
            self.remoteData.status[source] = .upToDate
            return true
        }

        let status = await self.remoteDataAccess.refresh()
        XCTAssertEqual(status, .upToDate)
    }

    func testRefreshStale() async throws {
        await self.networkChecker.setConnected(true)
        self.remoteData.status[.app] = .upToDate
        self.remoteData.refreshBlock = { source in
            XCTFail("Should skip")
            return true
        }

        let status = await self.remoteDataAccess.refresh()
        XCTAssertEqual(status, .upToDate)
    }

    func testRefreshStaleNoNetwork() async throws {
        await self.networkChecker.setConnected(false)
        self.remoteData.status[.app] = .stale
        self.remoteData.refreshBlock = { source in
            XCTFail("Should skip")
            return true
        }

        let status = await self.remoteDataAccess.refresh()
        XCTAssertEqual(status, .stale)
    }

    func testRefreshOutOfDate() async throws {
        await self.networkChecker.setConnected(true)
        self.remoteData.status[.app] = .outOfDate
        self.remoteData.refreshBlock = { source in
            XCTAssertEqual(source, .app)
            self.remoteData.status[source] = .upToDate
            return true
        }

        let status = await self.remoteDataAccess.refresh()
        XCTAssertEqual(status, .upToDate)
    }

    func testRefreshOutOfDateNoNetwork() async throws {
        await self.networkChecker.setConnected(false)
        self.remoteData.status[.app] = .outOfDate
        self.remoteData.refreshBlock = { source in
            XCTFail("Should skip")
            return true
        }

        let status = await self.remoteDataAccess.refresh()
        XCTAssertEqual(status, .outOfDate)
    }

    func testFeatureFlags() async throws {
        let json = """
        {
           "feature_flags":[
              {
                 "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925",
                 "created":"2023-07-10T18:10:46.203",
                 "last_updated":"2023-07-10T18:10:46.203",
                 "platforms":[
                    "web"
                 ],
                 "flag":{
                    "name":"cool_flag",
                    "type":"static",
                    "reporting_metadata":{
                       "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"
                    }
                 }
              }
           ]
        }
        """

        self.remoteData.payloads = [
            RemoteDataPayload(
                type: "feature_flags",
                timestamp: Date(),
                data: try! AirshipJSON.from(json: json),
                remoteDataInfo: RemoteDataInfo(
                    url: URL(string: "some:url")!,
                    lastModifiedTime: nil,
                    source: .app
                )
            )
        ]

        let flagInfos = await self.remoteDataAccess.flagInfos
        let expected: [FeatureFlagInfo] = [
            FeatureFlagInfo(
                id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
                created: AirshipUtils.parseISO8601Date(from: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipUtils.parseISO8601Date(from: "2023-07-10T18:10:46.203")!,
                name: "cool_flag",
                reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: nil
                    )
                )
            )
        ]

        XCTAssertEqual(flagInfos, expected)
    }

    func testFeatureFlagsIgnoreInvalid() async throws {
        let json = """
        {
           "feature_flags":[
              {
                 "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925",
                 "created":"2023-07-10T18:10:46.203",
                 "last_updated":"2023-07-10T18:10:46.203",
                 "platforms":[
                    "web"
                 ],
                 "flag":{
                    "name":"cool_flag",
                    "type":"static",
                    "reporting_metadata":{
                       "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"
                    }
                 }
              },
              {
                "something": "invalid"
              }
           ]
        }
        """

        self.remoteData.payloads = [
            RemoteDataPayload(
                type: "feature_flags",
                timestamp: Date(),
                data: try! AirshipJSON.from(json: json),
                remoteDataInfo: RemoteDataInfo(
                    url: URL(string: "some:url")!,
                    lastModifiedTime: nil,
                    source: .app
                )
            )
        ]

        let flagInfos = await self.remoteDataAccess.flagInfos
        let expected: [FeatureFlagInfo] = [
            FeatureFlagInfo(
                id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
                created: AirshipUtils.parseISO8601Date(from: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipUtils.parseISO8601Date(from: "2023-07-10T18:10:46.203")!,
                name: "cool_flag",
                reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: nil
                    )
                )
            )
        ]

        XCTAssertEqual(flagInfos, expected)
    }

    func testFeatureFlagsIgnoreContact() async throws {
        let json = """
        {
           "feature_flags":[
              {
                 "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925",
                 "created":"2023-07-10T18:10:46.203",
                 "last_updated":"2023-07-10T18:10:46.203",
                 "platforms":[
                    "web"
                 ],
                 "flag":{
                    "name":"cool_flag",
                    "type":"static",
                    "reporting_metadata":{
                       "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"
                    }
                 }
              }
           ]
        }
        """

        self.remoteData.payloads = [
            RemoteDataPayload(
                type: "feature_flags",
                timestamp: Date(),
                data: try! AirshipJSON.from(json: json),
                remoteDataInfo: RemoteDataInfo(
                    url: URL(string: "some:url")!,
                    lastModifiedTime: nil,
                    source: .contact
                )
            )
        ]

        let flagInfos = await self.remoteDataAccess.flagInfos
        XCTAssertTrue(flagInfos.isEmpty)
    }
}
