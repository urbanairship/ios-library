/* Copyright Airship and Contributors */

/// A class that will run blocks in a FIFO order
/// NOTE: For internal use only. :nodoc:
public final class AirshipAsyncSerialQueue : Sendable {
    private let continuation: AsyncStream<@Sendable () async -> Void>.Continuation
    private let stream: AsyncStream<@Sendable () async -> Void>


    public init(priority: TaskPriority? = nil) {
        (
            self.stream,
            self.continuation
        ) = AsyncStream<@Sendable () async -> Void>.airshipMakeStreamWithContinuation()

        Task.detached(priority: priority) {
            for await next in self.stream {
                await next()
            }
        }
    }

    deinit {
        self.stop()
    }

    public func enqueue(work: @Sendable @escaping () async -> Void) {
        self.continuation.yield(work)
    }

    public func stop() {
        self.continuation.finish()
    }

    // Waits for all the current operations to be cleared
    public func waitForCurrentOperations() async {
        await withCheckedContinuation{ continuation in
            self.enqueue {
                continuation.resume()
            }
        }
    }
}
