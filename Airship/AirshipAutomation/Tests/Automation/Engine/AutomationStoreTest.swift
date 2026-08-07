/* Copyright Airship and Contributors */

import Testing
import Foundation
import CoreData

@testable @_spi(AirshipInternal)
import AirshipAutomation
@_spi(AirshipInternal) import AirshipCore

struct AutomationStoreTest {

    private let store: AutomationStore = {
        let appKey = UUID().uuidString
        return AutomationStore(
            appKey: appKey,
            inMemory: true,
            ledgerStore: LedgerStore(appKey: appKey, inMemory: true)
        )
    }()

    @Test
    func testUpsertNewSchedules() async throws {
        let data = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        let result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            #expect(existing == nil)
            return data[identifier]!
        }

        #expect(result == [data["foo"], data["bar"]])
    }

    @Test
    func testUpsertMixedSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]

        var result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            #expect(existing == nil)
            return original[identifier]!
        }

        #expect(result == [original["foo"], original["bar"]])

        var updated = original
        updated["baz"] = makeSchedule(identifer: "baz")
        updated["foo"]?.scheduleState = .finished

        result = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { [updated] identifier, existing in
            if let existing = existing {
                #expect(existing.equalsIgnoringLastModified(original[identifier]!))
            }
            return updated[identifier]!
        }

        #expect(result == [updated["foo"], updated["bar"], updated["baz"]])
    }

    @Test
    func testUpdate() async throws {
        let originalFoo = makeSchedule(identifer: "foo")

        _ = try await self.store.upsertSchedules(scheduleIDs: ["foo"]) { identifier, existing in
            return originalFoo
        }

        let triggerInfo = TriggeringInfo(
            context: AirshipTriggerContext(type: "foo", goal: 10.0, event: "event"),
            date: Date.distantPast
        )

        let preparedInfo = PreparedScheduleInfo(
            scheduleID: "full",
            productID: "some product",
            campaigns: "campaigns",
            contactID: "some contact",
            experimentResult: ExperimentResult(
                channelID: "some channel",
                contactID: "some contact",
                isMatch: true,
                reportingMetadata: [AirshipJSON.string("reporing")]
            ),
            triggerSessionID: "some trigger session id",
            priority: 0
        )

        let date = Date()
        let result = try await self.store.updateSchedule(scheduleID: "foo") { data in
            data.executionCount = 100
            data.triggerInfo = triggerInfo
            data.schedule.group = "bar"
            data.preparedScheduleInfo = preparedInfo
            data.scheduleState = .paused
            data.scheduleStateChangeDate = date
        }

        var expected = originalFoo
        expected.schedule.group = "bar"
        expected.executionCount = 100
        expected.triggerInfo = triggerInfo
        expected.preparedScheduleInfo = preparedInfo
        expected.scheduleStateChangeDate = date
        expected.scheduleState = .paused
        #expect(result!.equalsIgnoringLastModified(expected))
    }

    @Test
    func testUpsertFullData() async throws {
        var schedule = self.makeSchedule(identifer: "full")
        schedule.triggerInfo = TriggeringInfo(
            context: AirshipTriggerContext(type: "foo", goal: 10.0, event: "event"),
            date: Date.distantPast
        )

        schedule.preparedScheduleInfo = PreparedScheduleInfo(
            scheduleID: "full",
            productID: "some product",
            campaigns: "campaigns",
            contactID: "some contact",
            experimentResult: ExperimentResult(
                channelID: "some channel",
                contactID: "some contact",
                isMatch: true,
                reportingMetadata: [AirshipJSON.string("reporing")]
            ),
            triggerSessionID: "some trigger session id",
            priority: 0
        )


        let batchUpsertResult = try await self.store.upsertSchedules(scheduleIDs: ["full"]) { [schedule] identifier, existing in
            return schedule
        }

        #expect(batchUpsertResult.count == 1)

        let fetchResult = try await self.store.getSchedule(scheduleID: "full")
        #expect(fetchResult != nil)
        #expect(fetchResult!.lastScheduleModifiedDate >= batchUpsertResult[0].lastScheduleModifiedDate)
    }

    @Test
    func testUpdateDoesNotExist() async throws {
        let result = try await self.store.updateSchedule(scheduleID: "baz") { data in
            Issue.record()
        }

        #expect(result == nil)
    }

    @Test
    func testGetSchedules() async throws {
        let original = ["foo": makeSchedule(identifer: "foo"), "bar": makeSchedule(identifer: "bar")]
        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar"]) { identifier, existing in
            return original[identifier]!
        }

        let foo = try await self.store.getSchedule(scheduleID: "foo")
        #expect(foo!.equalsIgnoringLastModified(original["foo"]!))

        let bar = try await self.store.getSchedule(scheduleID: "bar")
        #expect(bar!.equalsIgnoringLastModified(original["bar"]!))

        let doesNotExist = try await self.store.getSchedule(scheduleID: "doesNotExist")
        #expect(doesNotExist == nil)
    }

    @Test
    func testGetSchedulesByGroup() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        let groupA = try await self.store.getSchedules(group: "groupA").sorted { l, r in
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["foo"]!, original["baz"]!].equalsIgnoringLastModified(groupA))
    }

    @Test
    func testDeleteIdentifiers() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        try await self.store.deleteSchedules(scheduleIDs: ["foo", "doesNotExist"])

        let remaining = try await self.store.getSchedules().sorted { l, r in
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["baz"]!, original["bar"]!].equalsIgnoringLastModified(remaining))
    }

    @Test
    func testDeleteGroup() async throws {
        let original = [
            "foo": makeSchedule(identifer: "foo", group: "groupA"),
            "bar": makeSchedule(identifer: "bar", group: "groupB"),
            "baz": makeSchedule(identifer: "baz", group: "groupA")
        ]

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["foo", "bar", "baz"]) { identifier, existing in
            return original[identifier]!
        }

        try await self.store.deleteSchedules(group: "groupA")

        let remaining = try await self.store.getSchedules().sorted { l, r in
            return l.schedule.identifier > r.schedule.identifier
        }

        #expect([original["bar"]!].equalsIgnoringLastModified(remaining))
    }

    @Test
    func testAssociatedData() async throws {
        let associatedData = try AirshipJSON.string("some data").toData()
        var schedule = self.makeSchedule(identifer: "bar")
        schedule.associatedData = associatedData

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["bar"]) { [schedule] identifier, existing in
            return schedule
        }

        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")

        #expect(fromStore == associatedData)
    }

    @Test
    func testAssociatedDataNull() async throws {
        let schedule = self.makeSchedule(identifer: "bar")

        let _ = try await self.store.upsertSchedules(scheduleIDs: ["bar"]) { [schedule] identifier, existing in
            return schedule
        }

        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")

        #expect(fromStore == nil)
    }

    @Test
    func testAssociatedNoSchedule() async throws {
        let fromStore = try await self.store.getAssociatedData(scheduleID: "bar")
        #expect(fromStore == nil)
    }

    @Test
    func testIsCurrent() async throws {
        let schedule = makeSchedule(identifer: "test")
        let _ = try await self.store.upsertSchedules(scheduleIDs: ["test"]) { identifier, existing in
            return schedule
        }

        let fullSchedule = try await self.store.getSchedule(scheduleID: "test")!

        var isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate,
            scheduleState: .idle
        )
        #expect(isCurrent)

        isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate,
            scheduleState: .paused
        )
        #expect(!(isCurrent))

        isCurrent = try await self.store.isCurrent(
            scheduleID: "test",
            lastScheduleModifiedDate: fullSchedule.lastScheduleModifiedDate.addingTimeInterval(1),
            scheduleState: .idle
        )
        #expect(!(isCurrent))
    }

    @Test
    func testIsCurrentNoSchedule() async throws {
        let isCurrent = try await self.store.isCurrent(
            scheduleID: "fake identifier",
            lastScheduleModifiedDate: Date(),
            scheduleState: .paused
        )
        #expect(!(isCurrent))
    }

    @Test
    func testBackfillLedgerEvents() {
        let timestamp = Date(timeIntervalSince1970: 1000)
        let legacyData = [
            makeLegacy(identifier: "a", executionCount: 3),
            makeLegacy(identifier: "b", executionCount: 0),
            makeLegacy(identifier: "c", executionCount: 1)
        ]

        let events = AutomationStore.backfillLedgerEvents(
            from: legacyData,
            timestamp: timestamp
        )

        // Only schedules with a non-zero legacy count are backfilled, each as a
        // single execution/backfill event with no trigger or shared scope.
        let expected: [LedgerEvent] = [
            .execution(
                .init(
                    scheduleID: "a",
                    sharedID: nil,
                    triggerID: nil,
                    timestamp: timestamp,
                    count: 3,
                    result: .backfill,
                    cancel: nil
                )
            ),
            .execution(
                .init(
                    scheduleID: "c",
                    sharedID: nil,
                    triggerID: nil,
                    timestamp: timestamp,
                    count: 1,
                    result: .backfill,
                    cancel: nil
                )
            )
        ]

        #expect(events == expected)
    }

    @Test
    func testBackfillLedgerEventsSkipsZeroCounts() {
        let events = AutomationStore.backfillLedgerEvents(
            from: [makeLegacy(identifier: "a", executionCount: 0)],
            timestamp: Date()
        )
        #expect(events.isEmpty)
    }

    @Test
    func testBackfillLedgerEventsEmptyInput() {
        let events = AutomationStore.backfillLedgerEvents(from: [], timestamp: Date())
        #expect(events.isEmpty)
    }

    // MARK: - Migration backfill (end-to-end)

    @Test
    func testMigrationBackfillsLegacyExecutionCounts() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        try Self.seedLegacySchedule(appKey: appKey, identifier: "legacy-1", triggeredCount: 5)

        let ledger = TestLedgerStore()
        let store = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: ledger)

        // Any store access drives the lazy legacy migration.
        let schedules = try await store.getSchedules()

        #expect(schedules.count == 1)
        #expect(schedules.first?.schedule.identifier == "legacy-1")
        #expect(schedules.first?.executionCount == 5)

        let recorded = await ledger.recorded
        #expect(recorded.count == 1)

        guard case .execution(let execution) = recorded.first else {
            Issue.record("Expected a single execution backfill event, got \(recorded)")
            return
        }

        #expect(execution.scheduleID == "legacy-1")
        #expect(execution.count == 5)
        #expect(execution.result == .backfill)
        #expect(execution.sharedID == nil)
        #expect(execution.triggerID == nil)
    }

    @Test
    func testMigrationDoesNotBackfillZeroCounts() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        try Self.seedLegacySchedule(appKey: appKey, identifier: "legacy-1", triggeredCount: 0)

        let ledger = TestLedgerStore()
        let store = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: ledger)

        let schedules = try await store.getSchedules()

        // The schedule still migrates, but a zero count produces no backfill.
        #expect(schedules.count == 1)
        #expect(await ledger.recorded.isEmpty)
    }

    @Test
    func testMigrationBackfillIsNotDuplicatedOnRerun() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        try Self.seedLegacySchedule(appKey: appKey, identifier: "legacy-1", triggeredCount: 5)

        // Shared across relaunches so the one-time backfill flag persists, exactly
        // as the app's data store would across process restarts.
        let dataStore = PreferenceDataStore(appKey: appKey)

        let firstLedger = TestLedgerStore()
        let firstStore = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: firstLedger, dataStore: dataStore)
        _ = try await firstStore.getSchedules()
        #expect(await firstLedger.recorded.count == 1)

        // Simulate a relaunch where the post-migration legacy delete had failed:
        // the legacy store is present again, but the new store already holds the
        // migrated schedule. Migration must bail without re-recording backfill.
        try Self.seedLegacySchedule(appKey: appKey, identifier: "legacy-1", triggeredCount: 5)

        let secondLedger = TestLedgerStore()
        let secondStore = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: secondLedger, dataStore: dataStore)
        let schedules = try await secondStore.getSchedules()

        #expect(schedules.count == 1)
        #expect(await secondLedger.recorded.isEmpty)
    }

    // MARK: - Current-store migration backfill (post-18, end-to-end)

    @Test
    func testMigrationBackfillsCurrentStoreExecutionCounts() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        // A schedule already living in the current (Swift) store, as it would after
        // an upgrade from SDK 18.0-20.x, with no Objective-C store involved.
        try Self.seedCurrentSchedule(appKey: appKey, identifier: "current-1", executionCount: 4)

        let ledger = TestLedgerStore()
        let store = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: ledger)

        let schedules = try await store.getSchedules()

        #expect(schedules.count == 1)
        #expect(schedules.first?.schedule.identifier == "current-1")
        #expect(schedules.first?.executionCount == 4)

        let recorded = await ledger.recorded
        #expect(recorded.count == 1)

        guard case .execution(let execution) = recorded.first else {
            Issue.record("Expected a single execution backfill event, got \(recorded)")
            return
        }

        #expect(execution.scheduleID == "current-1")
        #expect(execution.count == 4)
        #expect(execution.result == .backfill)
        #expect(execution.sharedID == nil)
        #expect(execution.triggerID == nil)
    }

    @Test
    func testCurrentStoreBackfillSkipsZeroCounts() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        try Self.seedCurrentSchedule(appKey: appKey, identifier: "current-1", executionCount: 0)

        let ledger = TestLedgerStore()
        let store = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: ledger)

        let schedules = try await store.getSchedules()

        #expect(schedules.count == 1)
        #expect(await ledger.recorded.isEmpty)
    }

    @Test
    func testCurrentStoreBackfillIsNotDuplicatedOnRerun() async throws {
        let appKey = UUID().uuidString
        defer { Self.cleanupStores(appKey: appKey) }

        try Self.seedCurrentSchedule(appKey: appKey, identifier: "current-1", executionCount: 4)

        // Shared across relaunches so the one-time backfill flag persists.
        let dataStore = PreferenceDataStore(appKey: appKey)

        let firstLedger = TestLedgerStore()
        let firstStore = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: firstLedger, dataStore: dataStore)
        _ = try await firstStore.getSchedules()
        #expect(await firstLedger.recorded.count == 1)

        // Relaunch: the current store still holds the schedule and, under the ledger,
        // its executionCount would also cover ledger-recorded executions. The backfill
        // must run only once, so no counts are re-recorded on the second launch.
        let secondLedger = TestLedgerStore()
        let secondStore = AutomationStore(appKey: appKey, inMemory: false, ledgerStore: secondLedger, dataStore: dataStore)
        _ = try await secondStore.getSchedules()

        #expect(await secondLedger.recorded.isEmpty)
    }

    // MARK: - Migration helpers

    /// Writes a single legacy `UAScheduleData` row into the pre-ledger
    /// `Automation-<appKey>.sqlite` store using the current legacy model, so the
    /// real `LegacyAutomationStore` inside `AutomationStore` will migrate it.
    private static func seedLegacySchedule(
        appKey: String,
        identifier: String,
        triggeredCount: Int
    ) throws {
        let modelURL = try #require(
            AirshipAutomationResources.bundle.url(
                forResource: "UAAutomation",
                withExtension: "momd"
            )
        )
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let storeURL = try storeDirectory()
            .appendingPathComponent("Automation-\(appKey).sqlite")

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        try context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: "UAScheduleData",
                into: context
            )
            entity.setValue(identifier, forKey: "identifier")
            entity.setValue(NSNumber(value: 1), forKey: "type") // actions
            entity.setValue("{}", forKey: "data")
            entity.setValue(NSNumber(value: 3), forKey: "dataVersion") // skip data migration
            entity.setValue(NSNumber(value: triggeredCount), forKey: "triggeredCount")
            try context.save()
        }

        if let store = coordinator.persistentStores.first {
            try coordinator.remove(store)
        }
    }

    /// Writes a single `UAScheduleEntity` row into the current (Swift)
    /// `AirshipAutomation-<appKey>.sqlite` store using the current model, so it is
    /// present before `AutomationStore` runs its one-time current-store backfill.
    private static func seedCurrentSchedule(
        appKey: String,
        identifier: String,
        executionCount: Int
    ) throws {
        let modelURL = try #require(
            AirshipAutomationResources.bundle.url(
                forResource: "AirshipAutomation",
                withExtension: "momd"
            )
        )
        let model = try #require(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        let storeURL = try storeDirectory()
            .appendingPathComponent("AirshipAutomation-\(appKey).sqlite")

        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        let schedule = AutomationSchedule(
            identifier: identifier,
            data: .actions(.string("actions")),
            triggers: []
        )
        let scheduleData = try JSONEncoder().encode(schedule)

        try context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: "UAScheduleEntity",
                into: context
            )
            entity.setValue(identifier, forKey: "identifier")
            entity.setValue(scheduleData, forKey: "schedule")
            entity.setValue(AutomationScheduleState.idle.rawValue, forKey: "scheduleState")
            entity.setValue(Date.distantPast, forKey: "scheduleStateChangeDate")
            entity.setValue(executionCount, forKey: "executionCount")
            try context.save()
        }

        if let store = coordinator.persistentStores.first {
            try coordinator.remove(store)
        }
    }

    private static func storeDirectory() throws -> URL {
        #if os(tvOS)
        let searchPath: FileManager.SearchPathDirectory = .cachesDirectory
        #else
        let searchPath: FileManager.SearchPathDirectory = .libraryDirectory
        #endif

        let base = try #require(
            FileManager.default.urls(for: searchPath, in: .userDomainMask).last
        )
        let directory = base.appendingPathComponent("com.urbanairship.no-backup")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private static func cleanupStores(appKey: String) {
        guard let directory = try? storeDirectory() else { return }
        let names = [
            "Automation-\(appKey).sqlite",
            "In-app-automation-\(appKey).sqlite",
            "AirshipAutomation-\(appKey).sqlite"
        ]
        for name in names {
            for suffix in ["", "-wal", "-shm"] {
                let path = directory.appendingPathComponent(name + suffix).path
                if FileManager.default.fileExists(atPath: path) {
                    try? FileManager.default.removeItem(atPath: path)
                }
            }
        }
    }

    private func makeLegacy(identifier: String, executionCount: Int) -> LegacyScheduleData {
        return LegacyScheduleData(
            scheduleData: AutomationScheduleData(
                schedule: AutomationSchedule(
                    identifier: identifier,
                    data: .actions(.string("actions")),
                    triggers: []
                ),
                scheduleState: .idle,
                lastScheduleModifiedDate: .distantPast,
                scheduleStateChangeDate: .distantPast,
                executionCount: executionCount,
                triggerSessionID: UUID().uuidString
            ),
            triggerDatas: []
        )
    }

    private func makeSchedule(identifer: String, group: String? = nil) -> AutomationScheduleData {
        let schedule = AutomationSchedule(
            identifier: identifer,
            data: .inAppMessage(
                InAppMessage(
                    name: "some name",
                    displayContent: .custom(.string("Custom"))
                )
            ),
            triggers: [],
            created: Date.distantPast,
            group: group
        )

        return AutomationScheduleData(
            schedule: schedule,
            scheduleState: .idle,
            lastScheduleModifiedDate: .distantPast,
            scheduleStateChangeDate: Date.distantPast,
            executionCount: 0,
            triggerSessionID: UUID().uuidString
        )
    }
}

extension [AutomationScheduleData] {
    func equalsIgnoringLastModified(_ other: [AutomationScheduleData]) -> Bool {
        guard count == other.count else { return false }
        return zip(self, other).allSatisfy { $0.equalsIgnoringLastModified($1) }
    }
}

extension AutomationScheduleData {
    func equalsIgnoringLastModified(_ other: AutomationScheduleData) -> Bool {
        schedule == other.schedule &&
        scheduleState == other.scheduleState &&
        scheduleStateChangeDate == other.scheduleStateChangeDate &&
        executionCount == other.executionCount &&
        triggerInfo == other.triggerInfo &&
        preparedScheduleInfo == other.preparedScheduleInfo &&
        associatedData == other.associatedData &&
        triggerSessionID == other.triggerSessionID
    }
}

/// Records everything written to it so migration backfill can be asserted.
private actor TestLedgerStore: LedgerStoreProtocol {
    private(set) var recorded: [LedgerEvent] = []

    func recordEvents(_ events: [LedgerEvent]) async throws {
        recorded.append(contentsOf: events)
    }

    func events(scheduleID: String, sharedID: String?) async throws -> [LedgerEvent] {
        return []
    }

    func deleteEvents(scopes: [LedgerScope]) async throws {}
}
