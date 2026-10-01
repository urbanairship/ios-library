// Copyright Urban Airship and Contributors

import Foundation
@_spi(AirshipInternal) import AirshipBasement

import AirshipCore
@_spi(AirshipInternal) import AirshipScenes

@MainActor
final class NativeLayoutPersistentDataStore: LayoutDataStorage {
    let messageID: String

    private var restoreID: String? = nil
    private var storage: [String: Data] = [:]

    // Saves are funneled through this queue so that they always execute one at a
    // time, in submission order. Without this, each `store(_:key:)` call kicked
    // off its own unstructured `Task`, and since those tasks race an async Core
    // Data round trip, an older task (with a stale snapshot) could finish
    // *after* a newer one and silently regress the persisted state.
    private let queue: AirshipAsyncSerialQueue

    // Coalesces a burst of `store(_:key:)` calls (e.g. every field of a form
    // flushed together on dismiss) into a single fetch+merge+save round trip
    // instead of one per key. `prepare(restoreID:)` waits for `queue` to fully
    // drain, so N per-key round trips previously meant dismiss-then-reopen
    // latency scaled with however many fields changed since the last flush.
    // At most one flush is ever in flight or queued: further `store` calls
    // while one is pending just add to `storage`, which the pending flush
    // reads at execution time, not at schedule time.
    private var flushScheduled = false

    private let save: @Sendable (MessageCenterMessage.AssociatedData.ViewState?) async -> Void
    private let fetch: @Sendable () async -> MessageCenterMessage.AssociatedData.ViewState?

    // `getNativeStateStorage` (MessageCenterList) can hand out a fresh instance
    // for a message ID while an earlier instance's flush for that *same* ID is
    // still in flight -- e.g. navigating away and quickly back before the
    // trailing save lands. Each instance's own `queue` only serializes that
    // instance's saves against itself, so two independent per-instance queues
    // can still race: instance A's fetch->merge->save can straddle instance
    // B's, landing after it and dropping the key only B knew about, because
    // A's fetch ran before B's save committed. Defaulting every production
    // instance onto this one queue serializes across instances too, not just
    // within one. Callers that need isolation (tests) pass their own `queue:`.
    private static let sharedQueue = AirshipAsyncSerialQueue()

    init(
        messageID: String,
        queue: AirshipAsyncSerialQueue = NativeLayoutPersistentDataStore.sharedQueue,
        onSave: @Sendable @escaping (MessageCenterMessage.AssociatedData.ViewState?) async -> Void,
        onFetch: @Sendable @escaping () async -> MessageCenterMessage.AssociatedData.ViewState?
    ) {
        self.messageID = messageID
        self.queue = queue
        self.save = onSave
        self.fetch = onFetch
    }

    func prepare(restoreID: String) async {
        // Wait for any in-flight saves to complete before reading persisted state
        await queue.waitForCurrentOperations()

        self.restoreID = restoreID

        guard let saved = await fetch() else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] no saved state found")
            return
        }

        guard saved.restoreID == restoreID else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] restoreID mismatch: stored=\(saved.restoreID) expected=\(restoreID)")
            self.clear()
            return
        }

        if
            let data = saved.state,
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data) {
            for (key, value) in decoded {
                let json = String(data: value, encoding: .utf8) ?? "<non-utf8>"
                AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] loaded key=\(key) value=\(json)")
            }
            self.storage = decoded
        } else {
            AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] saved state empty for restoreID=\(restoreID)")
        }
    }

    func store(_ state: Data?, key: String) {
        guard let restoreID else { return }
        storage[key] = state
        let json = state.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] storing key=\(key) value=\(json)")

        scheduleFlush(restoreID: restoreID)
    }

    private func scheduleFlush(restoreID: String) {
        guard !flushScheduled else { return }
        flushScheduled = true

        // `self` is captured strongly, on purpose: this store is owned by the
        // Scene's view model, which can be torn down as soon as `flush()`
        // returns from `tryDismiss`. The save must still land even if nothing
        // else is holding this instance by the time `queue` gets to it.
        queue.enqueue { [self, fetch, save] in
            let dirty = await self.consumeStorageSnapshot()

            // Merge every currently-known key into whatever is *currently*
            // persisted, instead of overwriting with a snapshot captured back
            // when some earlier `store` call ran. That way, another writer
            // instance for this same message that already landed a save this
            // instance never locally observed doesn't get clobbered. This
            // merge is necessary but not sufficient on its own -- it only
            // protects against a save that's already committed by the time
            // this fetch runs; two saves genuinely overlapping in time still
            // need `queue` itself to be shared across instances (see
            // `sharedQueue` above) so one of them can't straddle the other.
            var persisted = Self.decodeStorage(
                from: await fetch(),
                restoreID: restoreID
            )
            persisted.merge(dirty) { _, new in new }
            await save(Self.makeViewState(storage: persisted, restoreID: restoreID))
        }
    }

    private func consumeStorageSnapshot() -> [String: Data] {
        flushScheduled = false
        return storage
    }

    func retrieve(_ key: String) -> Data? {
        let result = storage[key]
        let json = result.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        AirshipLogger.debug("[SceneRestore] DataStore[\(messageID)] retrieve key=\(key) value=\(json)")
        return result
    }

    func clear() {
        storage.removeAll()
        guard let restoreID else {
            queue.enqueue { [save] in
                await save(nil)
            }
            return
        }

        queue.enqueue { [save] in
            await save(.init(restoreID: restoreID, state: nil))
        }
    }

    nonisolated private static func decodeStorage(
        from viewState: MessageCenterMessage.AssociatedData.ViewState?,
        restoreID: String
    ) -> [String: Data] {
        guard
            let viewState,
            viewState.restoreID == restoreID,
            let data = viewState.state,
            let decoded = try? JSONDecoder().decode([String: Data].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    nonisolated private static func makeViewState(
        storage: [String: Data],
        restoreID: String
    ) -> MessageCenterMessage.AssociatedData.ViewState? {
        let data = try? JSONEncoder().encode(storage)
        return .init(restoreID: restoreID, state: data)
    }
}
