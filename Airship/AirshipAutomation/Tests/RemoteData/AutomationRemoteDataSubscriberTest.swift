/* Copyright Airship and Contributors */

import XCTest

import AirshipCore
@testable
import AirshipAutomation

final class AutomationRemoteDataSubscriberTest: XCTestCase {
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let engine: TestAutomationEngine = TestAutomationEngine()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)

    private var subscriber: AutomationRemoteDataSubscriber!

    override func setUp() async throws {
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits
        )
    }

    func testSchedulingAutomations() async throws {
        let appSchedules = makeSchedules(source: .app)
        let contactSchedules = makeSchedules(source: .contact)

        let data = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: appSchedules,
                        constraints: []
                    ),
                    timestamp: Date()
                ),
                .contact: .init(
                    data: .init(
                        schedules: contactSchedules,
                        constraints: []
                    ),
                    timestamp: Date()
                )
            ]
        )

        await self.subscriber.subscribe()

        let appExpectation = expectation(description: "schedules saved")
        let contactExpectation = expectation(description: "schedules saved")

        await self.engine.setOnUpsert { schedules in
            if (schedules == appSchedules) {
                appExpectation.fulfill()
            } else if (schedules == contactSchedules) {
                contactExpectation.fulfill()
            } else {
                XCTFail()
            }
        }

        self.remoteDataAccess.updatesSubject.send(data)
        await self.fulfillment(of: [appExpectation, contactExpectation])
    }

    func testEmptyPayloadStopsSchedules() async throws {
        let appSchedules = makeSchedules(source: .app)

        await self.engine.setSchedules(appSchedules)

        let emptyData = InAppRemoteData(
            payloads: [:]
        )

        await self.subscriber.subscribe()

        let stopExpectation = expectation(description: "schedules stopped")
        await self.engine.setOnStop { schedules in
            XCTAssertEqual(schedules, appSchedules)
            stopExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(emptyData)
        await self.fulfillment(of: [stopExpectation])
    }

    func testIgnoreSchedulesNoLongerScheduled() async throws {
        await self.subscriber.subscribe()

        let date = Date()

        let firstUpdateSchedules = makeSchedules(source: .app, count: 4)
        let firstUpdate = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: firstUpdateSchedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: RemoteDataInfo(
                        url: URL(string: "some-url")!,
                        lastModifiedTime: nil,
                        source: .app
                    )
                )
            ]
        )

        let firstUpdateExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, firstUpdateSchedules)
            firstUpdateExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(firstUpdate)
        await self.fulfillment(of: [firstUpdateExpectation])

        await self.engine.setSchedules(firstUpdateSchedules)

        let secondUpdateSchedules = firstUpdateSchedules + makeSchedules(source: .app, count: 4, created: date)
        let secondUpdate = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: secondUpdateSchedules,
                        constraints: []
                    ),
                    timestamp: date + 100.0,
                    remoteDataInfo: RemoteDataInfo(
                        url: URL(string: "some-url")!,
                        lastModifiedTime: nil,
                        source: .app
                    )
                )
            ]
        )

        let secondUpdateExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { schedules in
            // Should still be the first update schedules since the second updates are older
            XCTAssertEqual(schedules, firstUpdateSchedules)
            secondUpdateExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(secondUpdate)
        await self.fulfillment(of: [secondUpdateExpectation])
    }

    func testOlderSchedulesMinSDKVersion() async throws {

        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits,
            airshipSDKVersion: "1.0.0"
        )
        await self.subscriber.subscribe()


        let date = Date()
        let firstUpdateSchedules = makeSchedules(source: .app, count: 4)
        let firstUpdate = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: firstUpdateSchedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: RemoteDataInfo(
                        url: URL(string: "some-url")!,
                        lastModifiedTime: nil,
                        source: .app
                    )
                )
            ]
        )



        let firstUpdateExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, firstUpdateSchedules)
            firstUpdateExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(firstUpdate)
        await self.fulfillment(of: [firstUpdateExpectation])

        await self.subscriber.unsubscribe()
        // Update sdk version
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits,
            airshipSDKVersion: "2.0.0"
        )
        await self.subscriber.subscribe()

        await self.engine.setSchedules(firstUpdateSchedules)

        let secondUpdateSchedules = firstUpdateSchedules + makeSchedules(
            source: .app, 
            count: 4,
            minSDKVersion: "2.0.0",
            created: date
        )

        let secondUpdate = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: secondUpdateSchedules,
                        constraints: []
                    ),
                    timestamp: date + 100.0
                )
            ]
        )

        let secondUpdateExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, secondUpdateSchedules)
            secondUpdateExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(secondUpdate)
        await self.fulfillment(of: [secondUpdateExpectation])
    }

    func testSamePayloadSkipsAutomations() async throws {
        await self.subscriber.subscribe()

        let date = Date()
        let schedules = makeSchedules(source: .app, count: 4)
        let update = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: schedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: RemoteDataInfo(
                        url: URL(string: "some-url")!,
                        lastModifiedTime: nil,
                        source: .app
                    )
                )
            ]
        )

        let expecation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            expecation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(update)
        self.remoteDataAccess.updatesSubject.send(update)
        await self.fulfillment(of: [expecation])
    }

    func testRemoteDataInfoChangeUpdatesSchedules() async throws {
        await self.subscriber.subscribe()

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        let date = Date()
        let schedules = try makeSchedules(source: .app, count: 4).map { schedule in
            var mutable = schedule
            mutable.metadata = try AirshipJSON.wrap(remoteDataInfo)
            return mutable
        }

        let firstExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            firstExpectation.fulfill()
        }



        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: schedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))

        await self.fulfillment(of: [firstExpectation])

        await self.engine.setSchedules(schedules)

        let updatedRemoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-other-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        let updatedSchedules = try schedules.map { schedule in
            var mutable = schedule
            mutable.metadata = try AirshipJSON.wrap(updatedRemoteDataInfo)
            return mutable
        }

        let secondExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, updatedSchedules)
            secondExpectation.fulfill()
        }

        // udpate again with different remote-data info
        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: updatedSchedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: updatedRemoteDataInfo
                )
            ]
        ))

        await self.fulfillment(of: [secondExpectation])
    }
    

    func testPayloadDateChangeAutomations() async throws {
        await self.subscriber.subscribe()

        let date = Date()
        let schedules = makeSchedules(source: .app, count: 4)

        let firstExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            firstExpectation.fulfill()
        }

        let remoteDateInfo = RemoteDataInfo(
            url: URL(string: "some-other-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: schedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDateInfo
                )
            ]
        ))

        await self.fulfillment(of: [firstExpectation])

        await self.engine.setSchedules(schedules)

        let secondExpectation = expectation(description: "schedules saved")
        await self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            secondExpectation.fulfill()
        }


        // update again with different date
        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: schedules,
                        constraints: []
                    ),
                    timestamp: date + 1,
                    remoteDataInfo: remoteDateInfo
                )
            ]
        ))
        await self.fulfillment(of: [secondExpectation])
    }

    func testConstraints() async throws {
        let appConstraints = [
            FrequencyConstraint(identifier: "foo", range: 100, count: 10),
            FrequencyConstraint(identifier: "bar", range: 100, count: 10)
        ]
        let contactConstraints = [
            FrequencyConstraint(identifier: "foo", range: 1, count: 1),
            FrequencyConstraint(identifier: "baz", range: 1, count: 1)
        ]

        let data = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [],
                        constraints: appConstraints
                    ),
                    timestamp: Date()
                ),
                .contact: .init(
                    data: .init(
                        schedules: [],
                        constraints: contactConstraints
                    ),
                    timestamp: Date()
                ),
            ]
        )

        await self.subscriber.subscribe()

        let expectation = expectation(description: "constraints saved")
        await self.frequencyLimits.setOnConstraints { constraints in
            XCTAssertEqual(constraints, appConstraints + contactConstraints)
            expectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(data)
        await self.fulfillment(of: [expectation])
    }

    // MARK: - Failed schedule tracking tests

    func testFailedScheduleCarriedForwardAndRetriedOnSDKUpdate() async throws {
        let date = Date()
        let scheduleA = makeSchedule(source: .app, created: date)
        let failedB = FailedScheduleRecord(
            identifier: "failed_schedule_B",
            createdDate: date,
            minSDKVersion: nil
        )

        // First sync (SDK 1.0.0): A succeeds, B fails
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits,
            airshipSDKVersion: "1.0.0"
        )
        await self.subscriber.subscribe()

        let firstExpectation = expectation(description: "first sync upsert")
        await self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, [scheduleA])
            firstExpectation.fulfill()
        }

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA],
                        constraints: [],
                        failedSchedules: [failedB]
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [firstExpectation])

        // Now simulate SDK update: recreate subscriber with new version
        await self.subscriber.unsubscribe()
        await self.engine.setSchedules([scheduleA])

        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits,
            airshipSDKVersion: "2.0.0"
        )
        await self.subscriber.subscribe()

        // Second sync: B now parses successfully
        let scheduleB = makeSchedule(
            source: .app,
            identifier: "failed_schedule_B",
            created: date
        )

        let secondExpectation = expectation(description: "retry sync upsert")
        await self.engine.setOnUpsert { schedules in
            let ids = Set(schedules.map { $0.identifier })
            XCTAssertTrue(ids.contains("failed_schedule_B"))
            secondExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA, scheduleB],
                        constraints: [],
                        failedSchedules: []
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [secondExpectation])
    }

    func testFailedScheduleNowParsesOnServerFix() async throws {
        let date = Date()
        let scheduleA = makeSchedule(source: .app, created: date)
        let failedB = FailedScheduleRecord(
            identifier: "failed_schedule_B",
            createdDate: date,
            minSDKVersion: nil
        )

        await self.subscriber.subscribe()

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        // First sync: A succeeds, B fails
        let firstExpectation = expectation(description: "first sync")
        await self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules.map { $0.identifier }, [scheduleA.identifier])
            firstExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA],
                        constraints: [],
                        failedSchedules: [failedB]
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [firstExpectation])

        await self.engine.setSchedules([scheduleA])

        // Second sync: server fixed B, new timestamp
        let scheduleB = makeSchedule(
            source: .app,
            identifier: "failed_schedule_B",
            created: date
        )

        let secondExpectation = expectation(description: "server fix sync")
        await self.engine.setOnUpsert { schedules in
            let ids = Set(schedules.map { $0.identifier })
            XCTAssertTrue(ids.contains("failed_schedule_B"))
            secondExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA, scheduleB],
                        constraints: [],
                        failedSchedules: []
                    ),
                    timestamp: date + 100,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [secondExpectation])
    }

    func testFailedScheduleRemovedFromRemoteData() async throws {
        let date = Date()
        let scheduleA = makeSchedule(source: .app, created: date)
        let failedB = FailedScheduleRecord(
            identifier: "failed_schedule_B",
            createdDate: date,
            minSDKVersion: nil
        )

        await self.subscriber.subscribe()

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        // First sync: A succeeds, B fails
        let firstExpectation = expectation(description: "first sync")
        await self.engine.setOnUpsert { _ in
            firstExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA],
                        constraints: [],
                        failedSchedules: [failedB]
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [firstExpectation])

        await self.engine.setSchedules([scheduleA])

        // Second sync: B removed entirely from remote data, new timestamp
        let secondExpectation = expectation(description: "second sync")
        await self.engine.setOnUpsert { schedules in
            let ids = schedules.map { $0.identifier }
            XCTAssertFalse(ids.contains("failed_schedule_B"))
            secondExpectation.fulfill()
        }

        self.remoteDataAccess.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA],
                        constraints: [],
                        failedSchedules: []
                    ),
                    timestamp: date + 100,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        ))
        await self.fulfillment(of: [secondExpectation])
    }

    func testSamePayloadWithFailuresSkipsProcessing() async throws {
        let date = Date()
        let scheduleA = makeSchedule(source: .app, created: date)
        let failedB = FailedScheduleRecord(
            identifier: "failed_schedule_B",
            createdDate: date,
            minSDKVersion: nil
        )

        await self.subscriber.subscribe()

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        let payload = InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: [scheduleA],
                        constraints: [],
                        failedSchedules: [failedB]
                    ),
                    timestamp: date,
                    remoteDataInfo: remoteDataInfo
                )
            ]
        )

        let upsertExpectation = expectation(description: "upsert called once")
        await self.engine.setOnUpsert { _ in
            upsertExpectation.fulfill()
        }

        // Send the same payload twice — upsert should only fire once
        self.remoteDataAccess.updatesSubject.send(payload)
        self.remoteDataAccess.updatesSubject.send(payload)
        await self.fulfillment(of: [upsertExpectation])
    }

    // MARK: - Helpers

    private func makeSchedules(
        source: RemoteDataSource,
        count: UInt = UInt.random(in: 1..<10),
        minSDKVersion: String? = nil,
        created: Date = Date()
    ) -> [AutomationSchedule] {
        return (1...count).map { _ in
            makeSchedule(source: source, minSDKVersion: minSDKVersion, created: created)
        }
    }

    private func makeSchedule(
        source: RemoteDataSource,
        identifier: String = UUID().uuidString,
        minSDKVersion: String? = nil,
        created: Date = Date()
    ) -> AutomationSchedule {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-test-url/")!,
            lastModifiedTime: nil,
            source: source
        )
        return AutomationSchedule(
            identifier: identifier,
            data: .actions(.string("actions")),
            triggers: [AutomationTrigger.activeSession(count: 1)],
            created: created,
            metadata: try! AirshipJSON.wrap([
                InAppRemoteData.remoteInfoMetadataKey: remoteDataInfo
            ]),
            minSDKVersion: minSDKVersion
        )
    }
}
