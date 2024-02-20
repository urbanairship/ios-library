/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

final class FeatureFlagRemoteDataAccessTest: XCTestCase {

    private let remoteData: TestRemoteData = TestRemoteData()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private var remoteDataAccess: FeatureFlagRemoteDataAccess!

    override func setUp() {
        self.remoteDataAccess = FeatureFlagRemoteDataAccess(
            remoteData: self.remoteData,
            date: date
        )
    }

    func testWaitForRefresh() async throws {
        let expectation = XCTestExpectation()
        self.remoteData.waitForRefreshBlock = { source, time in
            XCTAssertEqual(source, .app)
            XCTAssertEqual(time, 15.0)
            expectation.fulfill()
        }

        await self.remoteDataAccess.waitForRefresh()
        await self.fulfillment(of: [expectation])
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

        let remoteDataInfo = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag")
        let expected: [FeatureFlagInfo] = [
            FeatureFlagInfo(
                id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
                created: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
                name: "cool_flag",
                reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: nil
                    )
                )
            )
        ]

        XCTAssertEqual(remoteDataInfo.flagInfos, expected)
        XCTAssertEqual(remoteDataInfo.remoteDataInfo, self.remoteData.payloads.first?.remoteDataInfo)
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

        let flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        let expected: [FeatureFlagInfo] = [
            FeatureFlagInfo(
                id: "27f26d85-0550-4df5-85f0-7022fa7a5925",
                created: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipDateFormatter.date(fromISOString: "2023-07-10T18:10:46.203")!,
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

        let flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        XCTAssertTrue(flagInfos.isEmpty)
    }

    func testFeatureFlagsIgnoreInActive() async throws {
        let nowMs = self.date.now.millisecondsSince1970
        let json = """
        {
           "feature_flags":[
              {
                 "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925",
                 "created":"2023-07-10T18:10:46.203",
                 "last_updated":"2023-07-10T18:10:46.203",
                 "flag":{
                    "name":"cool_flag",
                    "type":"static",
                    "reporting_metadata":{
                       "flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"
                    },
                    "time_criteria": {
                      "start_timestamp": \(nowMs),
                      "end_timestamp": \(nowMs + 5000)
                    }
                 },
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

        var flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        XCTAssertFalse(flagInfos.isEmpty)

        self.date.offset = 4.9
        flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        XCTAssertFalse(flagInfos.isEmpty)

        self.date.offset = 5.0
        flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        XCTAssertTrue(flagInfos.isEmpty)
    }
}
