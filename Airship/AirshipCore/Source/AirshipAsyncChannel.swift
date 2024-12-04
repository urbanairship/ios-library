/* Copyright Airship and Contributors */

import Foundation
public import Combine

/// Simple implementation of a `channel` that allows multiple AsyncStreams of the same data.
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

public extension AirshipAsyncChannel {

    /// Makes a stream that is nonisolated from the actor by wrapping the
    /// actor stream in an async stream.
    /// - Parameters:
    ///     - bufferPolicy: The buffer policy.
    ///     - initialValue: Optional initial value closure. If provided and the value is nil, it will finish the stream.
    ///     - transform: Transforms the channel values to the stream value. If nil, it a value is mapped to nil it will finish the stream.
    /// - Returns: An AsyncStream.
    nonisolated func makeNonIsolatedStream<R: Sendable>(
        bufferPolicy: BufferPolicy = .unbounded,
        initialValue: (@Sendable () async -> R?)? = nil,
        transform: @escaping @Sendable (T) async -> R?
    ) -> AsyncStream<R> {
        return AsyncStream<R> { [weak self] continuation in
            let task = Task { [weak self] in
                guard let stream = await self?.makeStream() else {
                    return
                }

                if let initialValue {
                    guard let value = await initialValue() else {
                        continuation.finish()
                        return
                    }

                    continuation.yield(value)
                }

                for await update in stream.map(transform) {
                    if let update {
                        continuation.yield(update)
                    } else {
                        continuation.finish()
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Makes a stream that is nonisolated from the actor by wrapping the
    /// actor stream in an async stream.
    /// - Parameters:
    ///     - bufferPolicy: The buffer policy.
    ///     - initialValue: Optional initial value closure. If provided and the value is nil, it will finish the stream.
    ///     - transform: Transforms the channel values to the stream value. If nil, it a value is mapped to nil it will finish the stream.
    /// - Returns: An AsyncStream.
    nonisolated func makeNonIsolatedStream(
        bufferPolicy: BufferPolicy = .unbounded,
        initialValue: (@Sendable () async -> T)? = nil
    ) -> AsyncStream<T> {
        return makeNonIsolatedStream(
            bufferPolicy: bufferPolicy,
            initialValue: initialValue,
            transform: { $0 }
        )
    }

    /// Makes a stream that is nonisolated from the actor by wrapping the
    /// actor stream in an async stream. Values will only be emitted if they are different than the previous value.
    /// - Parameters:
    ///     - bufferPolicy: The buffer policy.
    ///     - initialValue: Optional initial value closure. If provided and the value is nil, it will finish the stream.
    /// - Returns: An AsyncStream.
    nonisolated func makeNonIsolatedDedupingStream<R: Sendable&Equatable>(
        bufferPolicy: BufferPolicy = .unbounded,
        initialValue: (@Sendable () async -> R?)? = nil,
        transform: @escaping @Sendable (T) async -> R?
    ) -> AsyncStream<R> {
        return AsyncStream<R> { [weak self] continuation in
            let task = Task { [weak self] in
                guard let stream = await self?.makeStream() else {
                    return
                }

                var last: R? = nil

                if let initialValue {
                    guard let value = await initialValue() else {
                        continuation.finish()
                        return
                    }

                    continuation.yield(value)
                    last = value
                }

                for await update in stream.map(transform) {
                    guard let update else {
                        continuation.finish()
                        return
                    }

                    if update != last {
                        continuation.yield(update)
                        last = update
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Makes a stream that is nonisolated from the actor by wrapping the
    /// actor stream in an async stream. Values will only be emitted if they are different than the previous value.
    /// - Parameters:
    ///     - bufferPolicy: The buffer policy.
    ///     - initialValue: Optional initial value closure. If provided and the value is nil, it will finish the stream.
    /// - Returns: An AsyncStream.
    nonisolated func makeNonIsolatedDedupingStream(
        bufferPolicy: BufferPolicy = .unbounded,
        initialValue: (@Sendable () async -> T?)? = nil
    ) -> AsyncStream<T> where T: Equatable {
        return makeNonIsolatedDedupingStream(
            bufferPolicy: bufferPolicy,
            initialValue: initialValue,
            transform: { $0 }
        )
    }
}

public extension AsyncStream where Element : Sendable {

    /// Creates a combine publisher from an AsyncStream.
    /// - Note: for internal use only.  :nodoc:
    var airshipPublisher: AnyPublisher<Element?, Never>{
        let subject = CurrentValueSubject<Element?, Never>(nil)
        Task { [weak subject] in
            for await update in self {
                guard let subject else { return }
                subject.send(update)
            }
        }
        return subject.eraseToAnyPublisher()
    }

}
