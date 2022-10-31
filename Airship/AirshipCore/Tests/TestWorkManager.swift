import Foundation
import Combine

@testable
import AirshipCore

class TestWorkManager : NSObject, AirshipWorkManagerProtocol {
    let rateLimitor = TestWorkRateLimiter()
    private let conditionsMonitor = WorkConditionsMonitor()
    private let backgroundTasks = WorkBackgroundTasks()
    let workers: Workers = Workers()
    private let notificationCenter = NotificationCenter.default
    private var subscriptions: Set<AnyCancellable> = Set()

    /// Shared instance
    static let shared = AirshipWorkManager()

    override init() {
        super.init()

        let task = Task { [weak self] in
            await self?.workers.run()
        }

        startBackgroundListener()

        AnyCancellable {
            task.cancel()
        }.store(in: &subscriptions)
    }


    private func startBackgroundListener() {
        var task: Task<Void, Never>? = nil
        let cancellable = self.notificationCenter.publisher(
            for: AppStateTracker.didEnterBackgroundNotification
        ).sink { _ in
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
                if (wait > 0) {
                    try? await Task.sleep(
                        nanoseconds: UInt64(wait * 1_000_000_000)
                    )
                }
                backgroundTask.dispose()
            }
        }

        self.notificationCenter.publisher(
            for: AppStateTracker.didBecomeActiveNotification
        ).sink { _ in
            task?.cancel()
        }.store(in: &self.subscriptions)

        AnyCancellable {
            cancellable.cancel()
            task?.cancel()
        }.store(in: &self.subscriptions)
    }

    @objc(registerWorkerWithForID:type:workHandler:)
    public func _registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest, AirshipWorkContinuation) -> Void
    ) {
        registerWorker(
             workID,
             type: type
        ) { workRequest in
            var continuation: AirshipWorkContinuation? = nil
            let cancel = { continuation?.cancel() }
            return await withTaskCancellationHandler(
                operation: {
                    return await withCheckedContinuation { taskContinuation in
                        continuation = AirshipWorkContinuation { result  in
                            taskContinuation.resume(returning: result)
                        }
                        workHandler(workRequest, continuation!)
                    }
                }, onCancel: {
                    cancel()
                }
            )
        }
    }

    public func registerWorker(
        _ workID: String,
        type: AirshipWorkerType,
        workHandler: @escaping (AirshipWorkRequest) async throws -> AirshipWorkResult
    ) {
        let worker = TestWorker(
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

    @objc
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

    @objc
    public func dispatchWorkRequest(_ request: AirshipWorkRequest) {
        Task {
            await self.workers.dispatchWorkRequest(request)
        }
    }
}

actor Workers {
    var workerMap: [String: [TestWorker]] = [:]
    private var workerContinuation: AsyncStream<TestWorker>.Continuation?
    private var workerStream: AsyncStream<TestWorker>

    init() {
        var escapee: AsyncStream<TestWorker>.Continuation? = nil
        self.workerStream = AsyncStream { continuation in
            escapee = continuation
        }
        self.workerContinuation = escapee
    }

    func addWorker(_ worker: TestWorker, workID: String) {
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
