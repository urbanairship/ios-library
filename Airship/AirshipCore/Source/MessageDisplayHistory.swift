/* Copyright Airship and Contributors */

import Foundation

/// NOTE: For internal use only. :nodoc:
public struct MessageDisplayHistory: Codable, Equatable, Sendable {
    public var lastImpression: LastImpression?
    public var lastDisplay: LastDisplay?

    public init(lastImpression: LastImpression? = nil, lastDisplay: LastDisplay? = nil) {
        self.lastImpression = lastImpression
        self.lastDisplay = lastDisplay
    }
    
    public struct LastImpression: Codable, Equatable, Sendable {
        public var date: Date
        public var triggerSessionID: String
        
        public init(date: Date, triggerSessionID: String) {
            self.date = date
            self.triggerSessionID = triggerSessionID
        }
    }

    public struct LastDisplay: Codable, Equatable, Sendable {
        public var triggerSessionID: String
        
        public init(triggerSessionID: String) {
            self.triggerSessionID = triggerSessionID
        }
    }
}

/// NOTE: For internal use only. :nodoc:
public protocol MessageDisplayHistoryStoreProtocol: Sendable {
    func set(
        _ history: MessageDisplayHistory,
        scheduleID: String
    )

    func get(
        scheduleID: String
    ) async -> MessageDisplayHistory
}

/// NOTE: For internal use only. :nodoc:
public final class MessageDisplayHistoryStore: MessageDisplayHistoryStoreProtocol {

    private let storageGetter: @Sendable (String) async throws -> Data?
    private let storageSetter: @Sendable (String, MessageDisplayHistory) async throws -> Void
    private let queue: AirshipAsyncSerialQueue
    
    public init(
        storageGetter: @escaping @Sendable (String) async throws -> Data?,
        storageSetter: @escaping @Sendable (String, MessageDisplayHistory) async throws -> Void,
        queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
    ) {
        self.storageGetter = storageGetter
        self.storageSetter = storageSetter
        self.queue = queue
    }

    public func set(_ history: MessageDisplayHistory, scheduleID: String) {
        queue.enqueue { [weak self] in
            do {
                try await self?.storageSetter(scheduleID, history)
            } catch {
                AirshipLogger.error("Failed to save message history \(error)")
            }
        }
    }

    public func get(scheduleID: String) async -> MessageDisplayHistory {
        return await withCheckedContinuation { continuation in
            queue.enqueue { [weak self] in
                do {
                    guard let data = try await self?.storageGetter(scheduleID) else {
                        continuation.resume(returning: MessageDisplayHistory())
                        return
                    }

                    let history = try JSONDecoder().decode(MessageDisplayHistory.self, from: data)
                    continuation.resume(returning: history)
                } catch {
                    AirshipLogger.error("Failed to save message history \(error)")
                    continuation.resume(returning: MessageDisplayHistory())
                }
            }
        }
    }
}
