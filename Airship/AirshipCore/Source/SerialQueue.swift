/* Copyright Airship and Contributors */

import Foundation

// An actor that will run a task with a result in order.
/// NOTE: For internal use only. :nodoc:
public actor AirshipSerialQueue {
    private var nextTaskNumber = 0
    private var currentTaskNumber = 0
    private var currentTask: Task<Void, Never>?

    public init() {}
    
    public func run<T: Sendable>(work: @escaping @Sendable () async throws -> T) async throws -> T {
        let myTaskNumber = nextTaskNumber
        nextTaskNumber = nextTaskNumber + 1

        while myTaskNumber != currentTaskNumber {
            await self.currentTask?.value
            if myTaskNumber != currentTaskNumber {
                await Task.yield()
            }
        }

        let task: Task<T, any Error> = Task {
            return try await work()
        }

        currentTask = Task {
            let _ = try? await task.value
            currentTaskNumber += 1
            self.currentTask = nil
        }

        return try await task.value
    }

    public func runSafe<T: Sendable>(work: @escaping @Sendable () async -> T) async -> T {
        let myTaskNumber = nextTaskNumber
        nextTaskNumber = nextTaskNumber + 1

        while myTaskNumber != currentTaskNumber {
            await self.currentTask?.value
            if myTaskNumber != currentTaskNumber {
                await Task.yield()
            }
        }

        let task: Task<T, Never> = Task {
            return await work()
        }

        currentTask = Task {
            let _ = await task.value
            currentTaskNumber += 1
            self.currentTask = nil
        }

        return await task.value
    }
}
