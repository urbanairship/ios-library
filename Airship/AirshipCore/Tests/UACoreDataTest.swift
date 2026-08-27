/* Copyright Airship and Contributors */

import CoreData
import Testing
import Foundation

@testable @_spi(AirshipInternal) import AirshipCore

/// `UACoreData` hands every caller the same background context, and callers rely
/// on that to make each `perform` block atomic with respect to the others. These
/// cover the two ways that guarantee used to break.
struct UACoreDataTest {

    private struct Boom: Error {}

    private static let entityName = "UAEventData"

    private func makeCoreData(inMemory: Bool = true) throws -> UACoreData {
        guard
            let modelURL = AirshipCoreResources.bundle.url(
                forResource: "UAEvents", withExtension: "momd"
            )
        else {
            throw Boom()
        }

        return UACoreData(
            name: "UAEvents",
            modelURL: modelURL,
            inMemory: inMemory,
            stores: ["UACoreDataTest-\(UUID().uuidString).sqlite"]
        )
    }

    private func insertRow(_ context: NSManagedObjectContext, identifier: String) {
        let object = NSEntityDescription.insertNewObject(
            forEntityName: Self.entityName, into: context
        )
        object.setValue(identifier, forKey: "identifier")
        object.setValue("test", forKey: "type")
        object.setValue(Date(), forKey: "storeDate")
    }

    private func rowCount(_ context: NSManagedObjectContext) throws -> Int {
        try context.count(for: NSFetchRequest<any NSFetchRequestResult>(entityName: Self.entityName))
    }

    /// Getting the container suspends while stores load, so concurrent callers
    /// must share one in-flight context creation rather than each building their
    /// own — two contexts would run `perform` blocks in parallel. The suspension
    /// is present for in-memory and on-disk stores alike; in-memory keeps this
    /// off the file system.
    @Test
    func testConcurrentCallersShareOneContext() async throws {
        let coreData = try makeCoreData()

        let identities = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await coreData.performWithResult { context in
                        ObjectIdentifier(context).hashValue
                    }
                }
            }

            var collected: [Int] = []
            for try await identity in group {
                collected.append(identity)
            }
            return collected
        }

        #expect(Set(identities).count == 1)
    }

    /// A block that throws after mutating the shared context must not leave those
    /// changes pending for the next `saveIfChanged` to commit — including one in
    /// an unrelated read.
    @Test
    func testFailedWriteIsNotCommittedByALaterRead() async throws {
        let coreData = try makeCoreData()

        await #expect(throws: Boom.self) {
            try await coreData.perform { context in
                self.insertRow(context, identifier: "partial-one")
                self.insertRow(context, identifier: "partial-two")
                throw Boom()
            }
        }

        let count = try await coreData.performWithResult { try self.rowCount($0) }
        #expect(count == 0)
    }

    /// The delete-then-reinsert shape used by ledger compaction: a failure between
    /// the two halves must not leave a pending mass delete behind.
    @Test
    func testFailedDeleteAndReinsertLeavesStoreIntact() async throws {
        let coreData = try makeCoreData()

        try await coreData.perform { context in
            for index in 0..<5 {
                self.insertRow(context, identifier: "seed-\(index)")
            }
        }
        #expect(try await coreData.performWithResult { try self.rowCount($0) } == 5)

        await #expect(throws: Boom.self) {
            try await coreData.perform { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
                try context.fetch(request).forEach(context.delete)
                throw Boom()
            }
        }

        let count = try await coreData.performWithResult { try self.rowCount($0) }
        #expect(count == 5)
    }

    /// A successful block still commits.
    @Test
    func testSuccessfulWriteCommits() async throws {
        let coreData = try makeCoreData()

        try await coreData.perform { context in
            self.insertRow(context, identifier: "kept")
        }

        let count = try await coreData.performWithResult { try self.rowCount($0) }
        #expect(count == 1)
    }
}

extension UACoreDataTest {

    /// A store that fails to load must not wedge permanently, and concurrent
    /// callers must share one attempt rather than each building their own
    /// container over the same file.
    @Test
    func testFailedStoreLoadRecoversOnALaterCall() async throws {
        guard
            let modelURL = AirshipCoreResources.bundle.url(
                forResource: "UAEvents", withExtension: "momd"
            )
        else {
            throw Boom()
        }

        let storeName = "UACoreDataTest-load-\(UUID().uuidString).sqlite"
        // Mirror `UACoreData.storeSQLDirectory()`, which differs on tvOS.
        #if os(tvOS)
        let searchPath: FileManager.SearchPathDirectory = .cachesDirectory
        #else
        let searchPath: FileManager.SearchPathDirectory = .libraryDirectory
        #endif
        let directory = FileManager.default
            .urls(for: searchPath, in: .userDomainMask).last!
            .appendingPathComponent("com.urbanairship.no-backup")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // A directory where the sqlite file belongs makes the store fail to open.
        let blocker = directory.appendingPathComponent(storeName)
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)

        let coreData = UACoreData(
            name: "UAEvents", modelURL: modelURL, inMemory: false, stores: [storeName]
        )

        // Several callers race the same failing attempt.
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    do {
                        _ = try await coreData.performWithResult { try self.rowCount($0) }
                        return true
                    } catch {
                        return false
                    }
                }
            }
            for await succeeded in group {
                #expect(!succeeded)
            }
        }

        // Unblock: the store must now open rather than stay wedged.
        try FileManager.default.removeItem(at: blocker)
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: directory.appendingPathComponent(storeName + suffix)
                )
            }
        }

        let count = try await coreData.performWithResult { try self.rowCount($0) }
        #expect(count == 0)
    }
}
