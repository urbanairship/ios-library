/* Copyright Airship and Contributors */

import Foundation
@_spi(AirshipInternal) import AirshipBasement

/// An append-only file of captured records, newest last.
///
/// One JSON array per capture kind under Application Support. Deliberately not Core Data:
/// the push and event viewers need querying and a managed model, while this needs "append,
/// read back, throw it all away", and a file makes `purge()` a single unlink — which
/// matters when turning the capture off has to actually remove what it stored.
///
/// Writes are serialized on a private queue and coalesced, so a capture site can hand over a
/// record from any thread — including the logging thread — without paying for disk I/O
/// inline. Debug-only, so there is no migration: a file that no longer decodes is dropped.
final class AirshipDebugCaptureStore<Record: Codable & Sendable>: Sendable {

    /// Oldest records are dropped past this. A debug session's worth, bounded so a capture
    /// left on overnight can't fill the disk.
    private let limit: Int

    private let fileURL: URL
    private let queue: DispatchQueue
    private let pending: AirshipAtomicValue<[Record]>
    private let flushScheduled: AirshipAtomicValue<Bool>
    private let isAccepting: AirshipAtomicValue<Bool>

    init(name: String, limit: Int = 1000, directory: URL? = nil) {
        self.limit = limit
        self.queue = DispatchQueue(
            label: "com.urbanairship.debug.capture.\(name)",
            qos: .utility
        )
        self.pending = .init([])
        self.flushScheduled = .init(false)
        self.isAccepting = .init(true)

        let base = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
        self.fileURL = base.appendingPathComponent("\(name).json")
    }

    /// Queues a record. Returns immediately; the write happens on the store's own queue.
    func append(_ record: Record) {
        guard isAccepting.value else { return }
        pending.update { $0.append(record) }
        scheduleFlush()
    }

    /// Reads everything currently on disk, oldest first. Records still queued in memory are
    /// flushed first, so a screen that reads right after a capture sees it.
    func load() async -> [Record] {
        await withCheckedContinuation { continuation in
            queue.async {
                self.flushLocked()
                continuation.resume(returning: self.readLocked())
            }
        }
    }

    /// Deletes the file and anything queued for it, and refuses records until `resume()`. Used
    /// when a capture is turned off: consent withdrawn means the data goes, not just the
    /// writes, and a capture site racing the purge must not write the file back.
    func purge() async {
        isAccepting.set(false)
        pending.set([])
        await withCheckedContinuation { continuation in
            queue.async {
                try? FileManager.default.removeItem(at: self.fileURL)
                continuation.resume()
            }
        }
    }

    /// Accepts records again after a `purge()`, discarding any that slipped into the queue
    /// while it was refusing. A no-op when the store is already accepting, so it is safe to
    /// call on every screen appearance.
    func resume() {
        guard !isAccepting.value else { return }
        pending.set([])
        isAccepting.set(true)
    }

    // MARK: - Private

    private func scheduleFlush() {
        // One flush in flight at a time: a burst of records costs a single rewrite rather
        // than one per record, which matters for logs.
        guard flushScheduled.setValue(true) else { return }

        queue.asyncAfter(deadline: .now() + 0.25) {
            self.flushScheduled.set(false)
            self.flushLocked()
        }
    }

    /// Must run on `queue`.
    private func flushLocked() {
        var incoming: [Record] = []
        pending.update {
            incoming = $0
            $0 = []
        }
        guard !incoming.isEmpty, isAccepting.value else { return }

        let combined = (readLocked() + incoming).suffix(limit)
        guard let data = try? JSONEncoder().encode(Array(combined)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Must run on `queue`.
    private func readLocked() -> [Record] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Record].self, from: data)) ?? []
    }

    private static func defaultDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(
            "com.urbanairship.debug.capture",
            isDirectory: true
        )
    }
}
