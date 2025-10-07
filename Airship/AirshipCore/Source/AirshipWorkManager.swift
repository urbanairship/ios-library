/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Manages work for the Airship SDK
final class AirshipWorkManager: AirshipWorkManagerProtocol, Sendable {

    private let rateLimiter = WorkRateLimiter()
    private let conditionsMonitor = WorkConditionsMonitor()
    private let backgroundTasks = WorkBackgroundTasks()
    private let workers: Workers = Workers()
    private let startTask: Task<Void, Never>
    private let backgroundWaitTask: AirshipMainActorValue<(any AirshipCancellable)?> = AirshipMainActorValue(nil)
    private let queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
    private let backgroundWorkRequests: AirshipMainActorValue<[AirshipWorkRequest]> = AirshipMainActorValue([])

    /// Shared instance
    static let shared = AirshipWorkManager()

    deinit {
        startTask.cancel()
    }

    init() {
        self.startTask = Task { [workers = self.workers] in
            await workers.run()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: AppStateTracker.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: AppStateTracker.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    @preconcurrency
    @MainActor
    private func applicationDidEnterBackground() {
        backgroundWaitTask.value?.cancel()

        guard Airship.isFlying else {
            return
        }

        let cancellable: CancellableValueHolder<Task<Void, Never>> = CancellableValueHolder { task in
            task.cancel()
        }

        let background = try? self.backgroundTasks.beginTask("AirshipWorkManager") { [cancellable] in
            cancellable.cancel()
        }

        let isDynamicBackgroundWaitTimeEnabled = Airship.config.airshipConfig.isDynamicBackgroundWaitTimeEnabled
        let pending = backgroundWorkRequests.value

        cancellable.value = Task { [workers, pending] in
            await withTaskCancellationHandler {

                for request in pending {
                    await workers.dispatchWorkRequest(request)
                }

                guard isDynamicBackgroundWaitTimeEnabled else {
                    try? await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
                    background?.cancel()
                    return
                }

                let sleep = await workers.calculateBackgroundWaitTime(maxTime: 15.0)
                try? await Task.sleep(nanoseconds: UInt64(max(sleep, 5.0) * 1_000_000_000))
                background?.cancel()
            } onCancel: {
                background?.cancel()
            }
        }

        backgroundWaitTask.set(cancellable)
    }

    @objc
    @preconcurrency
    @MainActor
    private func applicationDidBecomeActive() {
        backgroundWaitTask.value?.cancel()
    }

    public func registerWorker(
        _ workID: String,
        workHandler: @Sendable @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    ) {
        let worker = Worker(
            workID: workID,
            conditionsMonitor: conditionsMonitor,
            rateLimiter: rateLimiter,
            backgroundTasks: backgroundTasks,
            workHandler: workHandler
        )

        queue.enqueue { [workers = self.workers] in
            await workers.addWorker(worker)
        }
    }

    public func setRateLimit(
        _ rateLimitID: String,
        rate: Int,
        timeInterval: TimeInterval
    ) {
        Task { [rateLimiter = self.rateLimiter] in
            try? await rateLimiter.set(
                rateLimitID,
                rate: rate,
                timeInterval: timeInterval
            )
        }
    }

    public func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        queue.enqueue { [workers = self.workers] in
            await workers.dispatchWorkRequest(request)
        }
    }

    @MainActor
    func autoDispatchWorkRequestOnBackground(_ request: AirshipWorkRequest) {
        backgroundWorkRequests.update { $0.append(request) }
    }
}

private actor Workers {
    private var workers: [Worker] = []
    private let workerContinuation: AsyncStream<Worker>.Continuation
    private let workerStream: AsyncStream<Worker>
    private var isRunning: Bool = false

    init() {
        (self.workerStream, self.workerContinuation) = AsyncStream<Worker>.airshipMakeStreamWithContinuation()
    }

    deinit {
        workerContinuation.finish()
    }

    func addWorker(_ worker: Worker) {
        workers.append(worker)
        workerContinuation.yield(worker)
    }

    func calculateBackgroundWaitTime(maxTime: TimeInterval) async -> TimeInterval {
        let workersToProcess = self.workers
        guard !workersToProcess.isEmpty else { return 0.0 }

        let maxWaitTime = await withTaskGroup(
            of: TimeInterval.self,
            returning: TimeInterval.self
        ) { group in
            for worker in workersToProcess {
                group.addTask {
                    return await worker.calculateBackgroundWaitTime(maxTime: maxTime)
                }
            }

            var currentMax: TimeInterval = 0.0
            for await result in group {
                currentMax = max(currentMax, result)
            }
            return currentMax
        }

        return maxWaitTime
    }

    func dispatchWorkRequest(_ request: AirshipWorkRequest) async {
        for worker in workers where worker.workID == request.workID {
            await worker.addWork(request: request)
        }
    }

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        await withTaskGroup(of: Void.self) { group in
            for await worker in self.workerStream {
                guard !Task.isCancelled else { break }
                group.addTask {
                    await worker.run()
                }
            }
        }
    }
}

