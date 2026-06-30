/* Copyright Airship and Contributors */

import Testing
import Foundation

import AirshipCore
@testable @_spi(AirshipInternal)
import AirshipAutomation

struct AutomationRemoteDataSubscriberTest {
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let engine: TestAutomationEngine = TestAutomationEngine()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)

    private var subscriber: AutomationRemoteDataSubscriber

    init() {
        self.subscriber = AutomationRemoteDataSubscriber(
            dataStore: dataStore,
            remoteDataAccess: remoteDataAccess,
            engine: engine,
            frequencyLimitManager: frequencyLimits
        )
    }

    @Test
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

        await confirmation(expectedCount: 2) { confirm in
            let latch = Latch(2)
            await self.engine.setOnUpsert { schedules in
                if (schedules == appSchedules) {
                    confirm()
                } else if (schedules == contactSchedules) {
                    confirm()
                } else {
                    Issue.record()
                }
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(data)
            await latch.wait()
        }
    }

    @Test
    func testEmptyPayloadStopsSchedules() async throws {
        let appSchedules = makeSchedules(source: .app)

        await self.engine.setSchedules(appSchedules)

        let emptyData = InAppRemoteData(
            payloads: [:]
        )

        await self.subscriber.subscribe()

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnStop { schedules in
                #expect(schedules == appSchedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(emptyData)
            await latch.wait()
        }
    }

    @Test
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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                #expect(schedules == firstUpdateSchedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(firstUpdate)
            await latch.wait()
        }

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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                // Should still be the first update schedules since the second updates are older
                #expect(schedules == firstUpdateSchedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(secondUpdate)
            await latch.wait()
        }
    }

    @Test
    mutating func testOlderSchedulesMinSDKVersion() async throws {

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



        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                #expect(schedules == firstUpdateSchedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(firstUpdate)
            await latch.wait()
        }

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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                #expect(schedules == secondUpdateSchedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(secondUpdate)
            await latch.wait()
        }
    }

    @Test
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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { scheduled in
                #expect(scheduled == schedules)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(update)
            self.remoteDataAccess.updatesSubject.send(update)
            await latch.wait()
        }
    }

    @Test
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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { scheduled in
                #expect(scheduled == schedules)
                confirm()
                await latch.signal()
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

            await latch.wait()
        }

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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { scheduled in
                #expect(scheduled == updatedSchedules)
                confirm()
                await latch.signal()
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

            await latch.wait()
        }
    }
    

    @Test
    func testPayloadDateChangeAutomations() async throws {
        await self.subscriber.subscribe()

        let date = Date()
        let schedules = makeSchedules(source: .app, count: 4)

        let remoteDateInfo = RemoteDataInfo(
            url: URL(string: "some-other-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { scheduled in
                #expect(scheduled == schedules)
                confirm()
                await latch.signal()
            }

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

            await latch.wait()
        }

        await self.engine.setSchedules(schedules)

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { scheduled in
                #expect(scheduled == schedules)
                confirm()
                await latch.signal()
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
            await latch.wait()
        }
    }

    @Test
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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.frequencyLimits.setOnConstraints { constraints in
                #expect(constraints == appConstraints + contactConstraints)
                confirm()
                await latch.signal()
            }

            self.remoteDataAccess.updatesSubject.send(data)
            await latch.wait()
        }
    }

    // MARK: - Failed schedule tracking tests

    @Test
    mutating func testFailedScheduleCarriedForwardAndRetriedOnSDKUpdate() async throws {
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

        let remoteDataInfo = RemoteDataInfo(
            url: URL(string: "some-url")!,
            lastModifiedTime: nil,
            source: .app
        )

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                #expect(schedules == [scheduleA])
                confirm()
                await latch.signal()
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
            await latch.wait()
        }

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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                let ids = Set(schedules.map { $0.identifier })
                #expect(ids.contains("failed_schedule_B"))
                confirm()
                await latch.signal()
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
            await latch.wait()
        }
    }

    @Test
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
        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                #expect(schedules.map { $0.identifier } == [scheduleA.identifier])
                confirm()
                await latch.signal()
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
            await latch.wait()
        }

        await self.engine.setSchedules([scheduleA])

        // Second sync: server fixed B, new timestamp
        let scheduleB = makeSchedule(
            source: .app,
            identifier: "failed_schedule_B",
            created: date
        )

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                let ids = Set(schedules.map { $0.identifier })
                #expect(ids.contains("failed_schedule_B"))
                confirm()
                await latch.signal()
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
            await latch.wait()
        }
    }

    @Test
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
        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { _ in
                confirm()
                await latch.signal()
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
            await latch.wait()
        }

        await self.engine.setSchedules([scheduleA])

        // Second sync: B removed entirely from remote data, new timestamp
        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { schedules in
                let ids = schedules.map { $0.identifier }
                #expect(!(ids.contains("failed_schedule_B")))
                confirm()
                await latch.signal()
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
            await latch.wait()
        }
    }

    @Test
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

        await confirmation { confirm in
            let latch = Latch(1)
            await self.engine.setOnUpsert { _ in
                confirm()
                await latch.signal()
            }

            // Send the same payload twice — upsert should only fire once
            self.remoteDataAccess.updatesSubject.send(payload)
            self.remoteDataAccess.updatesSubject.send(payload)
            await latch.wait()
        }
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

private actor Latch {
    private var remaining: Int
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ count: Int) {
        self.remaining = count
    }

    func signal() {
        remaining -= 1
        if remaining <= 0, let continuation {
            self.continuation = nil
            continuation.resume()
        }
    }

    func wait() async {
        if remaining <= 0 {
            return
        }
        await withCheckedContinuation { self.continuation = $0 }
    }
}
