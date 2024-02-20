/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Manages work for the Airship SDK
final class AirshipWorkManager: AirshipWorkManagerProtocol, Sendable {

    private let rateLimitor = WorkRateLimiter()
    private let conditionsMonitor = WorkConditionsMonitor()
    private let backgroundTasks = WorkBackgroundTasks()
    private let workers: Workers = Workers()
    private let startTask: Task<Void, Never>
    private let backgroundWaitTask: AirshipMainActorValue<AirshipCancellable?> = AirshipMainActorValue(nil)
    private let queue: AirshipAsyncSerialQueue = AirshipAsyncSerialQueue()
    private let backgroundWorkRequests: Atomic<[AirshipWorkRequest]> = Atomic([])

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
    @MainActor(unsafe)
    private func applicationDidEnterBackground() {
        backgroundWaitTask.value?.cancel()

        let cancellable: CancellableValueHolder<Task<Void, Never>> = CancellableValueHolder { task in
            task.cancel()
        }

        let background = try? self.backgroundTasks.beginTask("AirshipWorkManager") { [cancellable] in
            cancellable.cancel()
        }

        cancellable.value = Task {  [workers, backgroundWorkRequests]  in
            for request in backgroundWorkRequests.value {
                await workers.dispatchWorkRequest(request)
            }

            let sleep = await workers.calculateBackgroundWaitTime(maxTime: 15.0)
            try? await Task.sleep(nanoseconds: UInt64(max(sleep, 5.0) * 1_000_000_000))
            background?.cancel()
        }

        backgroundWaitTask.set(cancellable)
    }

    @objc
    @MainActor(unsafe)
    private func applicationDidBecomeActive() {
        backgroundWaitTask.value?.cancel()
    }

    public func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    ) {
        let worker = Worker(
            workID: workID,
            type: type,
            conditionsMonitor: conditionsMonitor,
            rateLimiter: rateLimitor,
            backgroundTasks: backgroundTasks,
            workHandler: workHandler
        )

        queue.enqueue { [workers = self.workers] in
            await workers.addWorker(worker, workID: workID)
        }

    }

    public func setRateLimit(
        _ rateLimitID: String,
        rate: Int,
        timeInterval: TimeInterval
    ) {
        Task { [rateLimitor = self.rateLimitor] in
            try? await rateLimitor.set(
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

    func autoDispatchWorkRequestOnBackground(_ request: AirshipWorkRequest) {
        backgroundWorkRequests.value.append(request)
    }
}

private actor Workers {
    private var workerMap: [String: [Worker]] = [:]
    private var workerContinuation: AsyncStream<Worker>.Continuation?
    private var workerStream: AsyncStream<Worker>

    init() {
        (self.workerStream, self.workerContinuation) = AsyncStream<Worker>.airshipMakeStreamWithContinuation()
    }

    func addWorker(_ worker: Worker, workID: String) {
        if workerMap[workID] == nil {
            workerMap[workID] = []
        }
        workerMap[workID]?.append(worker)
        workerContinuation?.yield(worker)
    }

    func calculateBackgroundWaitTime(
        maxTime: TimeInterval
    ) async -> TimeInterval {

        let workers: [Worker] = workerMap.values.reduce([], +)

        var result: TimeInterval = 0.0
        for worker in workers {
            let workerResult = await worker.calculateBackgroundWaitTime(maxTime: maxTime)
            result = max(result, workerResult)
        }

        return result
    }

    func dispatchWorkRequest(_ request: AirshipWorkRequest) async {
        guard let workers = self.workerMap[request.workID] else {
            return
        }

        for worker in workers {
            await worker.addWork(request: request)
        }
    }

    func run() async {
        await withTaskGroup(of: Void.self) { group in
            for await worker in self.workerStream {
                group.addTask {
                    await worker.run()
                }
            }
        }
    }
}

