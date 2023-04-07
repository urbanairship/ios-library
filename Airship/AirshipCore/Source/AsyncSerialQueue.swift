/* Copyright Airship and Contributors */

/// A class that will run blocks in a FIFO order
final class AsyncSerialQueue : Sendable {
    private let continuation: AsyncStream<@Sendable () async -> Void>.Continuation
    private let stream: AsyncStream<@Sendable () async -> Void>

    init(priority: TaskPriority? = nil) {
        (
            self.stream,
            self.continuation
        ) = AsyncStream<@Sendable () async -> Void>.makeStreamWithContinuation()

        Task.detached(priority: priority) {
            for await next in self.stream {
                await next()
            }
        }
    }

    deinit {
        self.stop()
    }

    func enqueue(work: @Sendable @escaping () async -> Void) {
        self.continuation.yield(work)
    }

    func stop() {
        self.continuation.finish()
    }

    // Waits for all the current operations to be cleared
    func waitForCurrentOperations() async {
        await withCheckedContinuation{ continuation in
            self.enqueue {
                continuation.resume()
            }
        }
    }
}
