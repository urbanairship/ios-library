/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Manages work for the Airship SDK
class AirshipWorkManager: AirshipWorkManagerProtocol {
    private let rateLimitor = WorkRateLimiter()
    private let conditionsMonitor = WorkConditionsMonitor()
    private let backgroundTasks = WorkBackgroundTasks()
    private let workers: Workers = Workers()
    private let notificationCenter = NotificationCenter.default
    private var subscriptions: Set<AnyCancellable> = Set()

    /// Shared instance
    static let shared = AirshipWorkManager()

    init() {
        let task = Task { [weak self] in
            await self?.workers.run()
        }

        startBackgroundListener()

        AnyCancellable {
            task.cancel()
        }
        .store(in: &subscriptions)
    }

    private func startBackgroundListener() {
        var task: Task<Void, Never>? = nil
        let cancellable = self.notificationCenter
            .publisher(
                for: AppStateTracker.didEnterBackgroundNotification
            )
            .sink { _ in
                task?.cancel()

                let backgroundTask = try? self.backgroundTasks.beginTask(
                    "Airship.WorkManager"
                ) {
                    task?.cancel()
                }

                guard let backgroundTask = backgroundTask else {
                    return
                }

                task = Task {
                    let wait = 300.0
                    if wait > 0 {
                        try? await Task.sleep(
                            nanoseconds: UInt64(wait * 1_000_000_000)
                        )
                    }
                    backgroundTask.dispose()
                }
            }

        self.notificationCenter
            .publisher(
                for: AppStateTracker.didBecomeActiveNotification
            )
            .sink { _ in
                task?.cancel()
            }
            .store(in: &self.subscriptions)

        AnyCancellable {
            cancellable.cancel()
            task?.cancel()
        }
        .store(in: &self.subscriptions)
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

        Task {
            await workers.addWorker(worker, workID: workID)
        }
    }

    public func setRateLimit(
        _ rateLimitID: String,
        rate: Int,
        timeInterval: TimeInterval
    ) {
        Task {
            try? await self.rateLimitor.set(
                rateLimitID,
                rate: rate,
                timeInterval: timeInterval
            )
        }
    }

    public func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        Task {
            await self.workers.dispatchWorkRequest(request)
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

