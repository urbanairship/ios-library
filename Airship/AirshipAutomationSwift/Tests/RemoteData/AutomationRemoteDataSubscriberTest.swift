/* Copyright Airship and Contributors */

import XCTest

import AirshipCore
@testable
import AirshipAutomationSwift

final class AutomationRemoteDataSubscriberTest: XCTestCase {
    private let remoteDataAcces: TestRemoteDataAccess = TestRemoteDataAccess()
    private let engine: TestAutomationEngine = TestAutomationEngine()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)

    private var subscriber: AutomationRemoteDataSubscriber!

    override func setUp() async throws {
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAcces,
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

        self.engine.setOnUpsert { schedules in
            if (schedules == appSchedules) {
                appExpectation.fulfill()
            } else if (schedules == contactSchedules) {
                contactExpectation.fulfill()
            } else {
                XCTFail()
            }
        }

        self.remoteDataAcces.updatesSubject.send(data)
        await self.fulfillment(of: [appExpectation, contactExpectation])
    }

    func testEmptyPayloadStopsSchedules() async throws {
        let appSchedules = makeSchedules(source: .app)

        self.engine.schedules = appSchedules

        let emptyData = InAppRemoteData(
            payloads: [:]
        )

        await self.subscriber.subscribe()

        let stopExpectation = expectation(description: "schedules stopped")
        self.engine.setOnStop { schedules in
            XCTAssertEqual(schedules, appSchedules)
            stopExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(emptyData)
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
        self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, firstUpdateSchedules)
            firstUpdateExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(firstUpdate)
        await self.fulfillment(of: [firstUpdateExpectation])

        self.engine.schedules = firstUpdateSchedules

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
        self.engine.setOnUpsert { schedules in
            // Should still be the first update schedules since the second updates are older
            XCTAssertEqual(schedules, firstUpdateSchedules)
            secondUpdateExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(secondUpdate)
        await self.fulfillment(of: [secondUpdateExpectation])
    }

    func testOlderSchedulesMinSDKVersion() async throws {

        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAcces,
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
        self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, firstUpdateSchedules)
            firstUpdateExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(firstUpdate)
        await self.fulfillment(of: [firstUpdateExpectation])

        await self.subscriber.unsubscribe()
        // Update sdk version
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAcces,
            engine: engine,
            frequencyLimitManager: frequencyLimits,
            airshipSDKVersion: "2.0.0"
        )
        await self.subscriber.subscribe()

        self.engine.schedules = firstUpdateSchedules

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
        self.engine.setOnUpsert { schedules in
            XCTAssertEqual(schedules, secondUpdateSchedules)
            secondUpdateExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(secondUpdate)
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
        self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            expecation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(update)
        self.remoteDataAcces.updatesSubject.send(update)
        await self.fulfillment(of: [expecation])
    }

    func testRemoteDataInfoChangeUpdatesSchedules() async throws {
        await self.subscriber.subscribe()

        let date = Date()
        let schedules = makeSchedules(source: .app, count: 4)

        let firstExpectation = expectation(description: "schedules saved")
        self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            firstExpectation.fulfill()
        }

        self.remoteDataAcces.updatesSubject.send(InAppRemoteData(
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
        ))

        await self.fulfillment(of: [firstExpectation])

        self.engine.schedules = schedules

        let secondExpectation = expectation(description: "schedules saved")
        self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            secondExpectation.fulfill()
        }


        // udpate again with different remote-data info
        self.remoteDataAcces.updatesSubject.send(InAppRemoteData(
            payloads: [
                .app: .init(
                    data: .init(
                        schedules: schedules,
                        constraints: []
                    ),
                    timestamp: date,
                    remoteDataInfo: RemoteDataInfo(
                        url: URL(string: "some-other-url")!,
                        lastModifiedTime: nil,
                        source: .app
                    )
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
        self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            firstExpectation.fulfill()
        }

        let remoteDateInfo = RemoteDataInfo(
            url: URL(string: "some-other-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        self.remoteDataAcces.updatesSubject.send(InAppRemoteData(
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

        self.engine.schedules = schedules

        let secondExpectation = expectation(description: "schedules saved")
        self.engine.setOnUpsert { scheduled in
            XCTAssertEqual(scheduled, schedules)
            secondExpectation.fulfill()
        }


        // update again with different date
        self.remoteDataAcces.updatesSubject.send(InAppRemoteData(
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

        self.remoteDataAcces.updatesSubject.send(data)
        await self.fulfillment(of: [expectation])
    }

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
        minSDKVersion: String? = nil,
        created: Date = Date()
    ) -> AutomationSchedule {
        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-test-url/")!,
            lastModifiedTime: nil,
            source: source
        )
        return AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(.string("actions")),
            triggers: [AutomationTrigger(type: .activeSession, goal: 1.0)],
            created: created,
            metadata: try! AirshipJSON.wrap([
                InAppRemoteData.remoteInfoMetadataKey: remoteDataInfo
            ]),
            minSDKVersion: minSDKVersion
        )
    }
}
