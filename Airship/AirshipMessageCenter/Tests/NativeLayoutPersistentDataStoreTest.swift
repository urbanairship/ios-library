/* Copyright Airship and Contributors */

import Testing
import Foundation

@_spi(AirshipInternal) @testable import AirshipCore
@_spi(AirshipInternal) @testable import AirshipMessageCenter

/// Regression coverage for MOBILE-5851: concurrent edits to a Scene form (each
/// backed by a `store(_:key:)` call) could silently lose data because saves
/// were fired as unstructured `Task`s (no ordering guarantee against an async
/// Core Data round trip) that each persisted a whole-dictionary snapshot
/// (clobbering any key a racing save didn't know about).
@MainActor
struct NativeLayoutPersistentDataStoreTest {
    private let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let config: RuntimeConfig = .testConfig()

    private let store: MessageCenterStore

    init() {
        let modelURL = AirshipMessageCenterResources.bundle
            .url(forResource: "UAInbox", withExtension: "momd")
        let coreData = UACoreData(
            name: "UAInbox",
            modelURL: modelURL!,
            inMemory: true,
            stores: [String(format: "Inbox-%@.sqlite", config.appCredentials.appKey)]
        )
        self.store = MessageCenterStore(
            config: config,
            dataStore: dataStore,
            coreData: coreData
        )
    }

    /// Reproduces the exact mechanism from the ticket: a save whose Core Data
    /// round trip takes *longer* is kicked off *before* a save that finishes
    /// quickly. Without serializing the saves, the slow/stale one can land on
    /// disk after the fast/fresh one and regress the persisted state -- even
    /// though the in-memory dictionary was already up to date with both keys.
    @Test
    func storeSerializesSavesSoASlowerOlderSaveCannotRegressState() async throws {
        let message = MessageCenterMessage.generateMessages(1)[0]
        try await store.updateMessages(messages: [message], lastModifiedTime: "")

        let callCount = AirshipAtomicValue<Int>(0)

        let dataStorage = NativeLayoutPersistentDataStore(
            messageID: message.id,
            onSave: { [store] state in
                let callIndex = callCount.getAndUpdate { $0 += 1 }
                if callIndex == 0 {
                    // Make the *first* save artificially slow so that, absent
                    // serialization, it would complete after the second one.
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                try? await store.updateAssociatedData(for: message.id) {
                    $0.viewState = state
                }
            },
            onFetch: { [store] in
                await store.associatedData(for: message.id).viewState
            }
        )

        await dataStorage.prepare(restoreID: "restore-1")

        dataStorage.store(Data("value-A".utf8), key: "fieldA")
        dataStorage.store(Data("value-B".utf8), key: "fieldB")

        // `prepare` awaits all pending saves before doing anything else, so
        // calling it again drains the queue deterministically -- no sleeping
        // and guessing at timings from the test side.
        await dataStorage.prepare(restoreID: "restore-1")

        let persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )

        #expect(persisted["fieldA"] == Data("value-A".utf8))
        #expect(persisted["fieldB"] == Data("value-B".utf8))
    }

    /// Reproduces the second half of the bug: even with saves serialized
    /// *within* a single writer, persisting a full local-dictionary snapshot
    /// is unsafe whenever a save doesn't originate from a dictionary that's
    /// aware of every previously-persisted key (e.g. an older
    /// `NativeLayoutPersistentDataStore` instance whose trailing save is still
    /// completing when a new one is created for the same message, which is
    /// exactly what `getNativeStateStorage` can produce). Each writer here
    /// only ever learns about its own key, so persistence must merge against
    /// the freshest data on disk, not overwrite it with a private snapshot.
    /// Writer A drains fully before writer B is even created, so there is no
    /// genuine concurrency here -- this isolates the per-key-merge
    /// requirement from the cross-instance *ordering* requirement covered by
    /// the test below.
    @Test
    func storeMergesPerKeyAgainstFreshlyPersistedStateSequentialWriters() async throws {
        let message = MessageCenterMessage.generateMessages(1)[0]
        try await store.updateMessages(messages: [message], lastModifiedTime: "")

        func makeWriter() -> NativeLayoutPersistentDataStore {
            NativeLayoutPersistentDataStore(
                messageID: message.id,
                queue: AirshipAsyncSerialQueue(),
                onSave: { [store] state in
                    try? await store.updateAssociatedData(for: message.id) {
                        $0.viewState = state
                    }
                },
                onFetch: { [store] in
                    await store.associatedData(for: message.id).viewState
                }
            )
        }

        let writerA = makeWriter()
        let writerB = makeWriter()

        await writerA.prepare(restoreID: "restore-1")
        writerA.store(Data("value-A".utf8), key: "fieldA")
        await writerA.prepare(restoreID: "restore-1")

        // Writer B never learns about "fieldA" locally -- its own `storage`
        // dictionary only ever contains "fieldB".
        await writerB.prepare(restoreID: "restore-1")
        writerB.store(Data("value-B".utf8), key: "fieldB")
        await writerB.prepare(restoreID: "restore-1")

        let persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )

        #expect(persisted["fieldA"] == Data("value-A".utf8))
        #expect(persisted["fieldB"] == Data("value-B".utf8))
    }

    /// The genuinely concurrent case the previous test doesn't cover: two
    /// independent `NativeLayoutPersistentDataStore` instances for the *same*
    /// message ID -- exactly what `getNativeStateStorage` hands out when a
    /// message is navigated away from and back to before the first
    /// instance's trailing save lands -- with overlapping flushes. Neither
    /// instance is constructed with an explicit `queue:` here, so both fall
    /// back to the shared default `queue:` production actually uses; without
    /// that sharing, writer A's slow fetch->merge->save can straddle writer
    /// B's fast one and land after it, dropping "fieldB" even though the
    /// per-key merge above is in place.
    @Test
    func storeMergesAcrossGenuinelyOverlappingWriters() async throws {
        let message = MessageCenterMessage.generateMessages(1)[0]
        try await store.updateMessages(messages: [message], lastModifiedTime: "")

        func makeWriter(slowSave: Bool) -> NativeLayoutPersistentDataStore {
            NativeLayoutPersistentDataStore(
                messageID: message.id,
                onSave: { [store] state in
                    if slowSave {
                        // Give the fast writer's flush time to fetch, merge
                        // and save first, so this one's fetch->save straddles
                        // it -- the scenario a per-instance queue can't stop.
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    try? await store.updateAssociatedData(for: message.id) {
                        $0.viewState = state
                    }
                },
                onFetch: { [store] in
                    await store.associatedData(for: message.id).viewState
                }
            )
        }

        let writerA = makeWriter(slowSave: true)
        let writerB = makeWriter(slowSave: false)

        await writerA.prepare(restoreID: "restore-1")
        await writerB.prepare(restoreID: "restore-1")

        writerA.store(Data("value-A".utf8), key: "fieldA")
        writerB.store(Data("value-B".utf8), key: "fieldB")

        // Both writers share one queue by default, so draining either one
        // drains both flushes.
        await writerA.prepare(restoreID: "restore-1")

        let persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )

        #expect(persisted["fieldA"] == Data("value-A".utf8))
        #expect(persisted["fieldB"] == Data("value-B".utf8))
    }

    /// A large form flushed in one burst (e.g. every field on dismiss) must not
    /// turn into one serialized fetch+save round trip per field: `prepare`
    /// waits for the whole queue to drain, so that would make dismiss-then-
    /// reopen latency scale with field count. Multiple `store` calls issued
    /// before the queue has a chance to run the first one must coalesce into a
    /// single round trip.
    @Test
    func storeCoalescesABurstOfKeysIntoASingleRoundTrip() async throws {
        let message = MessageCenterMessage.generateMessages(1)[0]
        try await store.updateMessages(messages: [message], lastModifiedTime: "")

        let saveCallCount = AirshipAtomicValue<Int>(0)

        let dataStorage = NativeLayoutPersistentDataStore(
            messageID: message.id,
            onSave: { [store] state in
                saveCallCount.getAndUpdate { $0 += 1 }
                try? await store.updateAssociatedData(for: message.id) {
                    $0.viewState = state
                }
            },
            onFetch: { [store] in
                await store.associatedData(for: message.id).viewState
            }
        )

        await dataStorage.prepare(restoreID: "restore-1")

        // All issued synchronously, before the queue's detached consumer task
        // gets a chance to run any of them.
        dataStorage.store(Data("value-A".utf8), key: "fieldA")
        dataStorage.store(Data("value-B".utf8), key: "fieldB")
        dataStorage.store(Data("value-C".utf8), key: "fieldC")

        // `prepare` itself calls `onFetch` once more (to check the restored
        // state), independent of the store's own flush, so `onSave` -- which
        // only the flush ever calls -- is the clean signal for "how many
        // round trips did the burst of `store` calls actually cause".
        await dataStorage.prepare(restoreID: "restore-1")

        #expect(saveCallCount.value == 1)

        let persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )
        #expect(persisted["fieldA"] == Data("value-A".utf8))
        #expect(persisted["fieldB"] == Data("value-B".utf8))
        #expect(persisted["fieldC"] == Data("value-C".utf8))
    }

    @Test
    func clearRemovesPersistedState() async throws {
        let message = MessageCenterMessage.generateMessages(1)[0]
        try await store.updateMessages(messages: [message], lastModifiedTime: "")

        let dataStorage = NativeLayoutPersistentDataStore(
            messageID: message.id,
            onSave: { [store] state in
                try? await store.updateAssociatedData(for: message.id) {
                    $0.viewState = state
                }
            },
            onFetch: { [store] in
                await store.associatedData(for: message.id).viewState
            }
        )

        await dataStorage.prepare(restoreID: "restore-1")
        dataStorage.store(Data("value-A".utf8), key: "fieldA")
        await dataStorage.prepare(restoreID: "restore-1")

        var persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )
        #expect(persisted["fieldA"] != nil)

        dataStorage.clear()
        await dataStorage.prepare(restoreID: "restore-1")

        persisted = try decodeStoredKeys(
            await store.associatedData(for: message.id).viewState
        )
        #expect(persisted.isEmpty)
    }

    private func decodeStoredKeys(
        _ viewState: MessageCenterMessage.AssociatedData.ViewState?
    ) throws -> [String: Data] {
        guard let data = viewState?.state else { return [:] }
        return try JSONDecoder().decode([String: Data].self, from: data)
    }
}
