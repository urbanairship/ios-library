/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

import Foundation

struct MessageDisplayHistory: Codable, Equatable, Sendable {
    var lastImpression: LastImpression?
    var lastDisplay: LastDisplay?

    init(lastImpression: LastImpression? = nil, lastDisplay: LastDisplay? = nil) {
        self.lastImpression = lastImpression
        self.lastDisplay = lastDisplay
    }
    
    struct LastImpression: Codable, Equatable, Sendable {
        var date: Date
        var triggerSessionID: String
    }

    struct LastDisplay: Codable, Equatable, Sendable {
        var triggerSessionID: String
    }
}


protocol MessageDisplayHistoryStoreProtocol: Sendable {
    func set(
        _ history: MessageDisplayHistory,
        scheduleID: String
    )

    func get(
        scheduleID: String
    ) async -> MessageDisplayHistory
}

final class MessageDisplayHistoryStore: MessageDisplayHistoryStoreProtocol {

    private let store: AutomationStore
    private let queue: AirshipAsyncSerialQueue

    init(store: AutomationStore, queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()) {
        self.store = store
        self.queue = queue
    }

    func set(_ history: MessageDisplayHistory, scheduleID: String) {
        queue.enqueue { [store] in
            do {
                try await store.updateSchedule(scheduleID: scheduleID) { data in
                    data.associatedData = try AirshipJSON.defaultEncoder.encode(history)
                }
            } catch {
                AirshipLogger.error("Failed to save message history \(error)")
            }
        }
    }

    func get(scheduleID: String) async -> MessageDisplayHistory {
        return await withCheckedContinuation { continuation in
            queue.enqueue { [store] in
                do {
                    guard let data = try await store.getAssociatedData(scheduleID: scheduleID) else {
                        continuation.resume(returning: MessageDisplayHistory())
                        return
                    }

                    let history: MessageDisplayHistory = try AirshipJSON.defaultDecoder.decode(MessageDisplayHistory.self, from: data)
                    continuation.resume(returning: history)
                } catch {
                    AirshipLogger.error("Failed to save message history \(error)")
                    continuation.resume(returning: MessageDisplayHistory())
                }
            }
        }
    }

}
