/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Manages work for the Airship SDK
final class AirshipWorkManager: AirshipWorkManagerProtocol, @unchecked Sendable {
    private let rateLimitor = WorkRateLimiter()
    private let conditionsMonitor = WorkConditionsMonitor()
    private let backgroundTasks = WorkBackgroundTasks()
    private let workers: Workers = Workers()
    private let startTask: Task<Void, Never>
    @MainActor
    private var backgroundWaitTask: AirshipCancellable? = nil
    private let queue: AsyncSerialQueue = AsyncSerialQueue()


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
        backgroundWaitTask?.cancel()

        let cancellable: CancellabelValueHolder<Task<Void, Never>> = CancellabelValueHolder { task in
            task.cancel()
        }

        let background = try? self.backgroundTasks.beginTask("AirshipWorkManager") { [cancellable] in
            cancellable.cancel()
        }

        cancellable.value = Task {
            let sleep = await workers.calculateBackgroundWaitTime(maxTime: 15.0)
            try? await Task.sleep(nanoseconds: UInt64(max(sleep, 5.0) * 1_000_000_000))
            background?.cancel()
        }

        backgroundWaitTask = cancellable
    }

    @objc
    @MainActor(unsafe)
    private func applicationDidBecomeActive() {
        backgroundWaitTask?.cancel()
    }

    public func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest, AirshipWorkContinuation) ->
            Void
    ) {
        registerWorker(
            workID,
            type: type
        ) { workRequest in
            let cancellable: CancellabelValueHolder<AirshipWorkContinuation> = CancellabelValueHolder { continuation in
                continuation.cancel()
            }
            
            return await withTaskCancellationHandler(
                operation: {
                    return await withCheckedContinuation { taskContinuation in
                        let continuation = AirshipWorkContinuation { result in
                            taskContinuation.resume(returning: result)
                        }
                        cancellable.value = continuation
                        workHandler(workRequest, continuation)
                    }
                },
                onCancel: {
                    cancellable.cancel()
                }
            )
        }
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
}

private actor Workers {
    private var workerMap: [String: [Worker]] = [:]
    private var workerContinuation: AsyncStream<Worker>.Continuation?
    private var workerStream: AsyncStream<Worker>

    init() {
        (self.workerStream, self.workerContinuation) = AsyncStream<Worker>.makeStreamWithContinuation()
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

