/* Copyright Airship and Contributors */

import Testing
import Foundation

@testable
import AirshipCore

@testable
import AirshipFeatureFlags

@_spi(AirshipInternal) import AirshipBasement

struct FeatureFlagRemoteDataAccessTest {

    private let remoteData: TestRemoteData = TestRemoteData()
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let remoteDataAccess: FeatureFlagRemoteDataAccess

    init() {
        self.remoteDataAccess = FeatureFlagRemoteDataAccess(
            remoteData: self.remoteData,
            date: date
        )
    }

    @Test
    func testBestEffortRefresh() async throws {
        await confirmation { confirmation in
            self.remoteData.waitForRefreshBlock = { source, time in
                #expect(source == .app)
                #expect(time == 15.0)
                confirmation()
            }

            await self.remoteDataAccess.bestEffortRefresh()
        }
    }

    @Test
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
                created: AirshipDateFormatter.date(from: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipDateFormatter.date(from: "2023-07-10T18:10:46.203")!,
                name: "cool_flag",
                reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: nil
                    )
                )
            )
        ]

        #expect(remoteDataInfo.flagInfos == expected)
        #expect(remoteDataInfo.remoteDataInfo == self.remoteData.payloads.first?.remoteDataInfo)
    }

    @Test
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
                created: AirshipDateFormatter.date(from: "2023-07-10T18:10:46.203")!,
                lastUpdated: AirshipDateFormatter.date(from: "2023-07-10T18:10:46.203")!,
                name: "cool_flag",
                reportingMetadata: try! AirshipJSON.wrap(["flag_id":"27f26d85-0550-4df5-85f0-7022fa7a5925"]),
                flagPayload: .staticPayload(
                    FeatureFlagPayload.StaticInfo(
                        variables: nil
                    )
                )
            )
        ]

        #expect(flagInfos == expected)
    }

    
    @Test
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
        #expect(flagInfos.isEmpty)
    }

    @Test
    func testFeatureFlagsIgnoreInActive() async throws {
        let nowMs = self.date.now.airshipMillisecondsSince1970
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
        #expect(!flagInfos.isEmpty)

        self.date.offset = 4.9
        flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        #expect(!flagInfos.isEmpty)

        self.date.offset = 5.0
        flagInfos = await self.remoteDataAccess.remoteDataFlagInfo(name: "cool_flag").flagInfos
        #expect(flagInfos.isEmpty)
    }
}
