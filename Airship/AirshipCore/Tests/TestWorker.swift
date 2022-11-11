import Combine
import Foundation

@testable import AirshipCore

/// Worker that handles queuing tasks and performing the actual work
actor TestWorker {
    private var workContinuation: AsyncStream<PendingRequest>.Continuation?
    private var workStream: AsyncStream<PendingRequest>
    var pending: [PendingRequest] = []
    private var tasks: Set<Task<Void, Error>> = Set()
    private var nextPendingID = 0

    private static let initialBackOff = 30.0
    private static let maxBackOff = 120.0

    let workID: String
    private let type: AirshipWorkerType
    private let conditionsMonitor: WorkConditionsMonitor
    let rateLimiter: TestWorkRateLimiter
    private let backgroundTasks: WorkBackgroundTasksProtocol
    private let workHandler:
        (AirshipWorkRequest) async throws -> AirshipWorkResult
    private let notificationCenter: NotificationCenter = NotificationCenter
        .default

    init(
        workID: String,
        type: AirshipWorkerType,
        conditionsMonitor: WorkConditionsMonitor,
        rateLimiter: TestWorkRateLimiter,
        backgroundTasks: WorkBackgroundTasksProtocol,
        workHandler: @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    ) {
        self.workID = workID
        self.type = type
        self.conditionsMonitor = conditionsMonitor
        self.rateLimiter = rateLimiter
        self.backgroundTasks = backgroundTasks
        self.workHandler = workHandler

        var escapee: AsyncStream<PendingRequest>.Continuation? = nil
        self.workStream = AsyncStream { continuation in
            escapee = continuation
        }
        self.workContinuation = escapee
    }

    func addWork(request: AirshipWorkRequest) {
        guard request.workID == self.workID else {
            AirshipLogger.error("Invalid request: \(request.workID)")
            return
        }

        var queueWork = false
        switch request.conflictPolicy {
        case .append:
            queueWork = true

        case .replace:
            pending.removeAll()
            tasks.forEach { $0.cancel() }
            tasks.removeAll()
            queueWork = true

        case .keep:
            queueWork = pending.isEmpty
        }

        if queueWork {
            let pendingID = nextPendingID
            nextPendingID += 1

            let pendingRequest = PendingRequest(id: pendingID, request: request)
            pending.append(pendingRequest)
            workContinuation?.yield(pendingRequest)
        }
    }

    func run() async {
        for await next in self.workStream {
            let task: Task<Void, Error> = Task { [weak self] in
                var attempt = 1
                while await self?.isValidRequest(next) == true {
                    var attemptTask: Task<Void, Error>? = nil
                    let disposable = Disposable {
                        attemptTask?.cancel()
                    }

                    await withTaskCancellationHandler { [attempt] in
                        let task = Task {
                            try Task.checkCancellation()
                            try await process(
                                pendingRequest: next,
                                attempt: attempt,
                                disposable: disposable
                            )
                        }

                        attemptTask = task
                        try? await task.result.get()
                    } onCancel: {
                        disposable.dispose()
                    }
                    attempt += 1

                }
            }

            tasks.insert(task)
            switch self.type {
            case .concurrent:
                Task {
                    try? await task.result.get()
                    tasks.remove(task)
                }
            case .serial:
                try? await task.result.get()
                tasks.remove(task)
            }
        }
    }

    private func isValidRequest(_ pendingRequest: PendingRequest) -> Bool {
        return self.pending.contains(pendingRequest)
    }

    private func removeRequest(_ pendingRequest: PendingRequest) {
        self.pending.removeAll { request in
            request.id == pendingRequest.id
        }
    }

    private func process(
        pendingRequest: PendingRequest,
        attempt: Int,
        disposable: Disposable
    ) async throws {
        let canonicalID = "\(workID)(\(pendingRequest.id))"
        try await prepare(pendingRequest: pendingRequest)
        try Task.checkCancellation()

        let backgroundTask = try backgroundTasks.beginTask(
            "Airship: \(canonicalID)"
        ) {
            disposable.dispose()
        }
        var result: AirshipWorkResult = .failure
        do {
            result = try await self.workHandler(pendingRequest.request)
        } catch {
            AirshipLogger.debug(
                "Failed to execute work \(canonicalID): \(error)"
            )
        }

        if result == .success {
            // Success
            AirshipLogger.trace(
                "Work \(canonicalID) finished"
            )
            self.removeRequest(pendingRequest)
            backgroundTask.dispose()
        } else {
            AirshipLogger.trace(
                "Work \(canonicalID) failed"
            )
            backgroundTask.dispose()
            try Task.checkCancellation()
            let backOff = min(
                TestWorker.maxBackOff,
                Double(attempt) * TestWorker.initialBackOff
            )
            AirshipLogger.trace(
                "Work \(canonicalID) backing off for \(backOff) seconds."
            )

            let cancellable = self.notificationCenter
                .publisher(
                    for: AppStateTracker.didEnterBackgroundNotification
                )
                .first()
                .sink { _ in
                    disposable.dispose()
                }

            try await sleep(backOff)
            cancellable.cancel()
        }
    }

    func calculateBackgroundWaitTime(maxTime: TimeInterval) async
        -> TimeInterval
    {
        switch self.type {
        case .serial:
            guard let pending = self.pending.first else {
                return 0.0
            }

            return await calculateBackgroundWaitTime(
                workRequest: pending.request,
                maxTime: maxTime
            )
        case .concurrent:
            var wait = 0.0
            for pendingRequest in self.pending {
                let requestWait = await self.calculateBackgroundWaitTime(
                    workRequest: pendingRequest.request,
                    maxTime: maxTime
                )
                wait = max(wait, requestWait)
            }

            return wait
        }
    }

    private func calculateBackgroundWaitTime(
        workRequest: AirshipWorkRequest,
        maxTime: TimeInterval
    ) async -> TimeInterval {
        guard
            await self.conditionsMonitor.checkConditions(
                workRequest: workRequest
            )
        else {
            return 0.0
        }

        guard !workRequest.rateLimitIDs.isEmpty else {
            return 1.0
        }
        let wait = await self.rateLimiter.nextAvailable(
            workRequest.rateLimitIDs
        )
        if wait > maxTime {
            return 0.0
        }
        return wait
    }

    private func prepare(pendingRequest: PendingRequest) async throws {
        let workRequest = pendingRequest.request

        if workRequest.initialDelay > 0 {
            let remainingDelay =
                pendingRequest.date.timeIntervalSinceNow
                - workRequest.initialDelay
            if remainingDelay > 0 {
                try await sleep(remainingDelay)
            }
        }

        if workRequest.rateLimitIDs.isEmpty {
            await self.conditionsMonitor.awaitConditions(
                workRequest: workRequest
            )
        } else {
            repeat {
                let rateLimit = await rateLimiter.nextAvailable(
                    workRequest.rateLimitIDs
                )
                if rateLimit > 0 {
                    try await Task.sleep(
                        nanoseconds: UInt64(rateLimit * 1_000_000_000)
                    )
                }
                await self.conditionsMonitor.awaitConditions(
                    workRequest: workRequest
                )
            } while await !rateLimiter.trackIfWithinLimit(
                workRequest.rateLimitIDs
            )
        }
    }

    private func sleep(_ time: TimeInterval) async throws {
        let sleep = UInt64(time) * 1_000_000_000
        try await Task.sleep(nanoseconds: sleep)
    }

    struct PendingRequest: Equatable {
        let id: Int
        let request: AirshipWorkRequest
        let date: Date = Date()
    }
}
