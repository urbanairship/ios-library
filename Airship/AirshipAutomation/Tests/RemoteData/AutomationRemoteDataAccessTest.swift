/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) import AirshipCore
@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipBasement

struct AutomationRemoteDataAccessTest {
    private let remoteData: TestRemoteData = TestRemoteData()
    private let networkChecker: TestNetworkChecker = TestNetworkChecker()
    private let subject: AutomationRemoteDataAccess

    init() throws {
        subject = AutomationRemoteDataAccess(
            remoteData: remoteData,
            network: networkChecker
        )
    }

    @Test
    func testIsCurrentTrue() async {
        let info = makeRemoteDataInfo()
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(schedule: schedule)
        #expect(isCurrent)
    }

    @Test
    func testIsCurrentFalse() async {
        let info = makeRemoteDataInfo()
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = false
        let isCurrent = await subject.isCurrent(schedule: schedule)
        #expect(!(isCurrent))
    }

    @Test
    func testIsCurrentNilRemoteDataInfo() async {
        let schedule = makeSchedule(remoteDataInfo: nil)

        remoteData.isCurrent = true
        let isCurrent = await subject.isCurrent(schedule: schedule)
        #expect(!(isCurrent))
    }

    @Test
    func testRequiresUpdateUpToDate() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        #expect(!(requiresUpdate))
    }

    @Test
    func testRequiresUpdateStale() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .stale

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        #expect(!(requiresUpdate))
    }

    @Test
    func testRequiresUpdateOutOfDate() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        #expect(requiresUpdate)
    }

    @Test
    func testRequiresUpdateNotCurrent() async {
        let info = makeRemoteDataInfo(.app)
        let schedule = makeSchedule(remoteDataInfo: info)

        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        #expect(requiresUpdate)
    }

    @Test
    func testRequiresUpdateNilRemoteDataInfo() async {
        remoteData.isCurrent = false
        remoteData.status[.app] = .upToDate

        let schedule = makeSchedule(remoteDataInfo: nil)

        let requiresUpdate = await subject.requiresUpdate(schedule: schedule)
        #expect(requiresUpdate)
    }

    @Test
    func testRequiresUpdateRightSource() async {
        remoteData.isCurrent = true
        remoteData.status[.app] = .outOfDate
        remoteData.status[.contact] = .upToDate

        let requiresUpdateContact = await subject.requiresUpdate(
            schedule: makeSchedule(remoteDataInfo: makeRemoteDataInfo(.contact))
        )
        #expect(!(requiresUpdateContact))

        let requiresUpdateApp = await subject.requiresUpdate(
            schedule: makeSchedule(remoteDataInfo: makeRemoteDataInfo(.app))
        )
        #expect(requiresUpdateApp)
    }

    @Test
    func testWaitForFullRefresh() async {
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        await confirmation { confirmed in
            self.remoteData.waitForRefreshBlock = { source, maxTime in
                #expect(source == .contact)
                #expect(maxTime == nil)
                confirmed()
            }


            await subject.waitFullRefresh(schedule: schedule)
        }
    }

    @Test
    func testWaitForFullRefreshNilInfo() async {
        await confirmation { confirmed in
            self.remoteData.waitForRefreshBlock = { source, maxTime in
                #expect(source == .app)
                #expect(maxTime == nil)
                confirmed()
            }

            let schedule = makeSchedule(remoteDataInfo: nil)
            await subject.waitFullRefresh(schedule: schedule)
        }
    }

    @Test
    func testBestEffortRefresh() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let schedule = makeSchedule(remoteDataInfo: info)

        let result = await confirmation { confirmed in
            self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
                #expect(source == .contact)
                #expect(maxTime == nil)
                confirmed()
            }

            return await subject.bestEffortRefresh(schedule: schedule)
        }
        #expect(result)
    }

    @Test
    func testBestEffortRefreshNotCurrentAfterAttempt() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        self.remoteData.status[.contact] = .stale

        let schedule = makeSchedule(remoteDataInfo: info)

        let result = await confirmation { confirmed in
            self.remoteData.waitForRefreshAttemptBlock = { source, maxTime in
                self.remoteData.isCurrent = false
                confirmed()
            }

            return await subject.bestEffortRefresh(schedule: schedule)
        }
        #expect(!(result))
    }

    @Test
    func testBestEffortRefreshNotCurrentReturnsNil() async {
        await self.networkChecker.setConnected(true)
        remoteData.isCurrent = false
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            Issue.record()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        #expect(!(result))
    }

    @Test
    func testBestEffortRefreshNotConnected() async {
        await self.networkChecker.setConnected(false)
        remoteData.isCurrent = true
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        self.remoteData.status[.contact] = .stale

        self.remoteData.waitForRefreshAttemptBlock = { _, _ in
            Issue.record()
        }

        let result = await subject.bestEffortRefresh(schedule: schedule)
        #expect(result)
    }

    @Test
    func testNotifyOutdated() async {
        let info = makeRemoteDataInfo(.contact)
        let schedule = makeSchedule(remoteDataInfo: info)

        await self.subject.notifyOutdated(schedule: schedule)
        #expect(self.remoteData.notifiedOutdatedInfos == [info])
    }
    
    @Test
    func testRemoteDataInfoIgnoresInvalidSchedules() throws {
             let validSchedule = """
                {
                    "id": "test_schedule",
                    "triggers": [
                        {
                            "type": "custom_event_count",
                            "goal": 1,
                            "id": "json-id"
                        }
                    ],
                    "group": "test_group",
                    "priority": 2,
                    "limit": 5,
                    "start": "2023-12-20T00:00:00Z",
                    "end": "2023-12-21T00:00:00Z",
                    "audience": {},
                    "delay": {},
                    "interval": 3600,
                    "type": "actions",
                    "actions": {
                        "foo": "bar",
                    },
                    "bypass_holdout_groups": true,
                    "edit_grace_period": 7,
                    "metadata": {},
                    "frequency_constraint_ids": ["constraint1", "constraint2"],
                    "message_type": "test_type",
                    "last_updated": "2023-12-20T12:30:00Z",
                    "created": "2023-12-20T12:00:00Z"
                }
                """
             let invalidSchedule = """
                {
                    "priority": 2,
                    "limit": 5,
                    "start": "2023-12-20T00:00:00Z",
                    "end": "2023-12-21T00:00:00Z",
                    "audience": {},
                    "delay": {},
                    "interval": 3600,
                    "type": "actions",
                    "actions": {
                        "foo": "bar",
                    },
                    "bypass_holdout_groups": true,
                    "edit_grace_period": 7,
                    "metadata": {},
                    "frequency_constraint_ids": ["constraint1", "constraint2"],
                    "message_type": "test_type",
                    "last_updated": "2023-12-20T12:30:00Z",
                    "created": "2023-12-20T12:00:00Z"
                }
                """

             let dataJson = try AirshipJSON.from(json: "{\"in_app_messages\": [\(validSchedule), \(invalidSchedule)]}")
             let payload = RemoteDataPayload(
                 type: "schedule_test",
                 timestamp: Date(),
                 data: dataJson,
                 remoteDataInfo: nil)

             let decoded: InAppRemoteData.Data = try payload.data.decode()
             #expect(1 == decoded.schedules.count)
             #expect("test_schedule" == decoded.schedules.first?.identifier)
             // Invalid schedule without ID can't be tracked
             #expect(decoded.failedSchedules.isEmpty)
         }
    
    @Test
    func testRemoteDataInfoTracksFailedSchedules() throws {
        let validSchedule = """
           {
               "id": "valid_schedule",
               "triggers": [
                   {
                       "type": "custom_event_count",
                       "goal": 1,
                       "id": "json-id"
                   }
               ],
               "type": "actions",
               "actions": {
                   "foo": "bar"
               }
           }
           """
        // Invalid schedule WITH an ID and created date (missing required triggers)
        let invalidScheduleWithID = """
           {
               "id": "failed_schedule_id",
               "created": "2023-12-20T12:00:00Z",
               "type": "actions",
               "actions": {
                   "foo": "bar"
               }
           }
           """

        let dataJson = try AirshipJSON.from(json: "{\"in_app_messages\": [\(validSchedule), \(invalidScheduleWithID)]}")
        let payload = RemoteDataPayload(
            type: "schedule_test",
            timestamp: Date(),
            data: dataJson,
            remoteDataInfo: nil)

        let decoded: InAppRemoteData.Data = try payload.data.decode()
        #expect(1 == decoded.schedules.count)
        #expect("valid_schedule" == decoded.schedules.first?.identifier)
        // Failed schedule with ID should be tracked
        #expect(decoded.failedSchedules.map { $0.identifier} == ["failed_schedule_id"])
        // Verify created date is captured as createdDate
        let expectedCreatedDate = AirshipDateFormatter.date(from: "2023-12-20T12:00:00Z")
        #expect(decoded.failedSchedules.first?.createdDate == expectedCreatedDate)
    }
    
    @Test
    func testFromPayloadsAggregatesFailedSchedules() throws {
        let validSchedule = """
           {
               "id": "valid_schedule",
               "triggers": [
                   {
                       "type": "custom_event_count",
                       "goal": 1,
                       "id": "json-id"
                   }
               ],
               "type": "actions",
               "actions": {
                   "foo": "bar"
               }
           }
           """
        // Invalid schedule WITH an ID and created date (missing required triggers)
        let invalidScheduleWithID = """
           {
               "id": "failed_schedule_id",
               "created": "2023-12-20T12:00:00Z",
               "type": "actions",
               "actions": {
                   "foo": "bar"
               }
           }
           """

        let dataJson = try AirshipJSON.from(json: "{\"in_app_messages\": [\(validSchedule), \(invalidScheduleWithID)]}")
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "https://airship.test")!,
            lastModifiedTime: nil,
            source: .app
        )
        let payload = RemoteDataPayload(
            type: "in_app_messages",
            timestamp: Date(),
            data: dataJson,
            remoteDataInfo: remoteDataInfo)
        
        let inAppRemoteData = InAppRemoteData.fromPayloads([payload])
        
        // Verify aggregate failedSchedules on InAppRemoteData
        #expect(inAppRemoteData.failedSchedules.map { $0.identifier} == ["failed_schedule_id"])
        // Verify created date is captured as createdDate
        let expectedCreatedDate = AirshipDateFormatter.date(from: "2023-12-20T12:00:00Z")
        #expect(inAppRemoteData.failedSchedules.first?.createdDate == expectedCreatedDate)
    }
    
    private func makeSchedule(remoteDataInfo: RemoteDataInfo?) -> AutomationSchedule {
        return AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(AirshipJSON.null),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            metadata: try! AirshipJSON.wrap([
                "com.urbanairship.iaa.REMOTE_DATA_INFO": remoteDataInfo
            ])
        )
    }
    private func makeRemoteDataInfo(_ source: RemoteDataSource = .app) -> RemoteDataInfo {
        return RemoteDataInfo(
            url: URL(string: "https://airship.test")!,
            lastModifiedTime: nil,
            source: source
        )
    }

}
