/* Copyright Airship and Contributors */

import Foundation

@preconcurrency
import Combine

/// NOTE: For internal use only. :nodoc:
public actor AirshipActorValue<T: Sendable> {

    private let subject: PassthroughSubject<T, Never> = PassthroughSubject()

    public private(set) var value: T {
        didSet {
            subject.send(value)
        }
    }

    public var updates: AsyncStream<T> {
        AsyncStream { continuation in
            let cancellable: AnyCancellable = subject.sink { value in
                continuation.yield(value)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public init(_ value: T) {
        self.value = value
    }

    public func set(_ value: T) {
        self.value = value
    }

    public func getAndUpdate(block: @Sendable (inout T) -> Void) -> T {
        block(&self.value)
        return self.value
    }

    public func update(block: @Sendable (inout T) -> Void) {
        block(&self.value)
    }
}

/// NOTE: For internal use only. :nodoc:
public final class AirshipMainActorValue<T: Sendable>: @unchecked Sendable {

    private let subject: PassthroughSubject<T, Never> = PassthroughSubject()

    @MainActor
    public private(set) var value: T {
        didSet {
            subject.send(value)
        }
    }

    @MainActor
    public var updates: AsyncStream<T> {
        AsyncStream { continuation in
            continuation.yield(value)

            let cancellable: AnyCancellable = subject.sink { value in
                continuation.yield(value)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public init(_ value: T) {
        self.value = value
    }

    @MainActor
    public func set(_ value: T) {
        self.value = value
    }

    @MainActor
    public func getAndUpdate(block: @Sendable (inout T) -> Void) -> T {
        block(&self.value)
        return value
    }

    @MainActor
    public func update(block: @Sendable (inout T) -> Void) {
        block(&self.value)
    }
}
