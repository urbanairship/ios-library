import Foundation
import Testing
@_spi(AirshipInternal) import AirshipBasement
@_spi(AirshipInternal) @testable import AirshipCore

@Suite("Worker offline", .timeLimit(.minutes(1)))
struct WorkerOfflineTests {

    private final class NoopBackgroundTasks: WorkBackgroundTasksProtocol {
        @MainActor
        func beginTask(
            _ name: String,
            expirationHandler: (@Sendable () -> Void)?
        ) throws -> any AirshipCancellable {
            return CancellableValueHolder<UInt>(value: 0) { _ in }
        }
    }

    private actor Calls {
        var ids: [String] = []
        func add(_ id: String) { ids.append(id) }
    }

    private func waitFor(_ timeout: TimeInterval = 2, _ condition: () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return await condition()
    }

    private func makeWorker(
        network: TestNetworkChecker,
        calls: Calls
    ) -> Worker {
        Worker(
            workID: "test",
            conditionsMonitor: WorkConditionsMonitor(networkMonitor: network),
            rateLimiter: WorkRateLimiter(),
            backgroundTasks: NoopBackgroundTasks(),
            workHandler: { request in
                await calls.add(request.extras?["id"] ?? "?")
                return .success
            }
        )
    }

    @Test("Replace request without network requirement runs while an earlier request waits for connectivity")
    func replaceWhileEarlierRequestWaitsForNetwork() async throws {
        let network = TestNetworkChecker()
        await network.setConnected(false)
        let calls = Calls()
        let worker = makeWorker(network: network, calls: calls)
        let running = Task { await worker.run() }
        defer { running.cancel() }

        await worker.addWork(request: AirshipWorkRequest(
            workID: "test",
            extras: ["id": "network"],
            requiresNetwork: true,
            conflictPolicy: .keepIfNotStarted
        ))
        try await Task.sleep(nanoseconds: 200_000_000)

        await worker.addWork(request: AirshipWorkRequest(
            workID: "test",
            extras: ["id": "local"],
            requiresNetwork: false,
            conflictPolicy: .replace
        ))

        let ran = await waitFor { await calls.ids.contains("local") }
        let seen = await calls.ids
        #expect(ran, "request without a network requirement never ran; ran: \(seen)")
    }

    @Test("Cancelling a request that waits for the network ends its wait")
    func cancelEndsNetworkWait() async throws {
        let network = TestNetworkChecker()
        await network.setConnected(false)
        let monitor = WorkConditionsMonitor(networkMonitor: network)
        let request = AirshipWorkRequest(workID: "test", requiresNetwork: true)

        let waiting = Task {
            try await monitor.awaitConditions(workRequest: request)
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        waiting.cancel()

        await #expect(throws: CancellationError.self) {
            try await waiting.value
        }
    }

    @Test("A request that waits for the network runs once it connects")
    func networkWaitEndsOnConnect() async throws {
        let network = TestNetworkChecker()
        await network.setConnected(false)
        let calls = Calls()
        let worker = makeWorker(network: network, calls: calls)
        let running = Task { await worker.run() }
        defer { running.cancel() }

        await worker.addWork(request: AirshipWorkRequest(
            workID: "test",
            extras: ["id": "network"],
            requiresNetwork: true
        ))
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(await calls.ids.isEmpty)

        await network.setConnected(true)

        let ran = await waitFor { await calls.ids.contains("network") }
        #expect(ran)
    }
}
