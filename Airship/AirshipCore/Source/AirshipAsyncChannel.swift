/* Copyright Airship and Contributors */

import Foundation

/// Simple implemenation of a `channel` that allows multiple AsyncStream of the same data.
/// - Note: for internal use only.  :nodoc:
public actor AirshipAsyncChannel<T: Sendable> {

    public enum BufferPolicy: Sendable {
        case unbounded
        case bufferingNewest(Int)
        case bufferingOldest(Int)

        fileprivate func toStreamPolicy() -> AsyncStream<T>.Continuation.BufferingPolicy {
            switch (self) {
            case .unbounded: return .unbounded
            case .bufferingOldest(let buffer): return .bufferingOldest(buffer)
            case .bufferingNewest(let buffer): return .bufferingNewest(buffer)
            }
        }
    }

    private var nextID: Int = 0
    private var listeners: [Int: Listener] = [:]

    public func send(_ value: T) async {
        listeners.values.forEach { listener in
            listener.send(value: value)
        }
    }

    public init() {}

    public func makeStream(bufferPolicy: BufferPolicy = .unbounded) -> AsyncStream<T> {
        let id = self.nextID
        nextID += 1
        
        return AsyncStream(bufferingPolicy: bufferPolicy.toStreamPolicy()) { continuation in
            let listener = Listener(continuation: continuation)
            listeners[id] = listener

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeListener(id: id)
                }
            }
        }
    }

    private func removeListener(id: Int) {
        self.listeners[id] = nil
    }

    final class Listener: Sendable {
        let continuation: AsyncStream<T>.Continuation

        init(continuation: AsyncStream<T>.Continuation) {
            self.continuation = continuation
        }

        func send(value: T) {
            self.continuation.yield(value)
        }
    }
}
