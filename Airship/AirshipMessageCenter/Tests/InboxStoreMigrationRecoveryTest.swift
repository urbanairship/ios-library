/* Copyright Airship and Contributors */

import CoreData
import XCTest

@testable import AirshipCore
@testable import AirshipMessageCenter

/// Verifies that a legacy inbox store which can no longer be migrated to the
/// current Core Data model is recovered (rebuilt) instead of leaving the inbox
/// permanently unreadable - matching the Android SDK's destructive-migration
/// fallback. See MOBILE-5681.
final class InboxStoreMigrationRecoveryTest: XCTestCase {

    private var storeName: String = ""
    private var storeURL: URL!

    private var modelURL: URL {
        AirshipMessageCenterResources.bundle.url(
            forResource: "UAInbox",
            withExtension: "momd"
        )!
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeName = "Inbox-\(UUID().uuidString).sqlite"
        let directory = try Self.noBackupDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        storeURL = directory.appendingPathComponent(storeName)
    }

    override func tearDownWithError() throws {
        // Remove the sqlite plus its -wal/-shm sidecars.
        for suffix in ["", "-wal", "-shm"] {
            let path = storeURL.path + suffix
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
        }
        try super.tearDownWithError()
    }

    /// A legacy (V2) store that cannot be migrated must throw - and must NOT be
    /// silently wiped - when recovery is disabled (every store except the inbox).
    func testUnmigratableStoreThrowsWithoutRecovery() async throws {
        try writeLegacyV2Store(at: storeURL)

        let coreData = UACoreData(
            name: "UAInbox",
            modelURL: modelURL,
            inMemory: false,
            stores: [storeName],
            recoverOnMigrationError: false
        )

        do {
            _ = try await messageCount(coreData)
            XCTFail("Expected an un-migratable store to throw when recovery is off")
        } catch {
            // Expected: the store cannot be opened with the current model.
        }

        // The store file must still be on disk - recovery off never deletes.
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    /// With recovery enabled (the inbox), the same un-migratable store is rebuilt
    /// and is usable afterwards. The rebuilt store is empty because inbox
    /// contents are re-synced from the server.
    func testUnmigratableStoreIsRecovered() async throws {
        try writeLegacyV2Store(at: storeURL)

        let coreData = UACoreData(
            name: "UAInbox",
            modelURL: modelURL,
            inMemory: false,
            stores: [storeName],
            recoverOnMigrationError: true
        )

        // Loads without throwing, and the rebuilt store is empty + writable.
        let initialCount = try await messageCount(coreData)
        XCTAssertEqual(initialCount, 0)

        try await coreData.perform { context in
            let message = NSEntityDescription.insertNewObject(
                forEntityName: "UAInboxMessage",
                into: context
            )
            message.setValue("recovered-message", forKey: "messageID")
        }

        let countAfterWrite = try await messageCount(coreData)
        XCTAssertEqual(countAfterWrite, 1)
    }

    /// The classifier is what protects against data loss: only Core Data
    /// migration failures may trigger a rebuild. Transient I/O failures (disk
    /// full, locked file) must be reported as non-recoverable so the store is
    /// left intact for a later attempt.
    func testMigrationErrorClassification() {
        let recoverable = [
            NSPersistentStoreIncompatibleVersionHashError,
            NSMigrationError,
            NSMigrationMissingSourceModelError,
            NSMigrationMissingMappingModelError,
            NSEntityMigrationPolicyError,
            NSInferredMappingModelError,
        ]
        for code in recoverable {
            let error = NSError(domain: NSCocoaErrorDomain, code: code)
            XCTAssertTrue(
                UACoreData.isMigrationError(error),
                "Code \(code) should be treated as a migration error"
            )
        }

        let transient = [
            NSFileWriteOutOfSpaceError,
            NSFileWriteNoPermissionError,
            NSFileReadNoSuchFileError,
            NSPersistentStoreTimeoutError,
        ]
        for code in transient {
            let error = NSError(domain: NSCocoaErrorDomain, code: code)
            XCTAssertFalse(
                UACoreData.isMigrationError(error),
                "Code \(code) is transient and must NOT trigger a wipe"
            )
        }

        // A migration error nested as an underlying error is still recoverable.
        let nested = NSError(
            domain: NSCocoaErrorDomain,
            code: NSValidationMultipleErrorsError,
            userInfo: [
                NSUnderlyingErrorKey: NSError(
                    domain: NSCocoaErrorDomain,
                    code: NSMigrationMissingMappingModelError
                )
            ]
        )
        XCTAssertTrue(UACoreData.isMigrationError(nested))
    }

    // MARK: - Helpers

    private func messageCount(_ coreData: UACoreData) async throws -> Int {
        try await coreData.performWithResult { context in
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: "UAInboxMessage"
            )
            return try context.count(for: request)
        }
    }

    /// Writes an inbox store using the legacy V2 model, which has no valid
    /// migration path to the current V4 model (the orphaned-mapping bug from
    /// MOBILE-5681), reproducing the customer's NSMigrationMissingMappingModelError.
    private func writeLegacyV2Store(at url: URL) throws {
        let v2URL = modelURL.appendingPathComponent("UAInbox 2.mom")
        let v2Model = try XCTUnwrap(
            NSManagedObjectModel(contentsOf: v2URL),
            "Could not load legacy V2 model from \(v2URL)"
        )

        let coordinator = NSPersistentStoreCoordinator(
            managedObjectModel: v2Model
        )
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: nil
        )

        let context = NSManagedObjectContext(
            concurrencyType: .privateQueueConcurrencyType
        )
        context.persistentStoreCoordinator = coordinator

        var thrown: Error?
        context.performAndWait {
            do {
                let message = NSEntityDescription.insertNewObject(
                    forEntityName: "UAInboxMessage",
                    into: context
                )
                message.setValue("legacy-message", forKey: "messageID")
                message.setValue("Legacy Title", forKey: "title")
                try context.save()
            } catch {
                thrown = error
            }
        }
        if let thrown { throw thrown }

        if let store = coordinator.persistentStores.first {
            try coordinator.remove(store)
        }
    }

    private static func noBackupDirectory() throws -> URL {
        let base = try XCTUnwrap(
            FileManager.default.urls(
                for: .libraryDirectory,
                in: .userDomainMask
            ).last
        )
        return base.appendingPathComponent("com.urbanairship.no-backup")
    }
}
