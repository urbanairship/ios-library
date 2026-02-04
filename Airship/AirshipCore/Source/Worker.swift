/* Copyright Airship and Contributors */

import Combine
import Foundation

/// Worker that handles queuing tasks and performing the actual work
actor Worker {
    private let workContinuation: AsyncStream<PendingRequest>.Continuation
    private let workStream: AsyncStream<PendingRequest>
    private var pending: [PendingRequest] = []
    private var inProgress: Set<PendingRequest> = Set()

    private var tasks: Set<Task<Void, any Error>> = Set()
    private var nextPendingID: Int = 0

    private static let initialBackOff = 30.0
    private static let maxBackOff = 120.0

    let workID: String
    private let conditionsMonitor: WorkConditionsMonitor
    private let rateLimiter: WorkRateLimiter
    private let backgroundTasks: any WorkBackgroundTasksProtocol
    private let workHandler: (AirshipWorkRequest) async throws -> AirshipWorkResult
    private let notificationCenter: NotificationCenter = NotificationCenter.default

    init(
        workID: String,
        conditionsMonitor: WorkConditionsMonitor,
        rateLimiter: WorkRateLimiter,
        backgroundTasks: any WorkBackgroundTasksProtocol,
        workHandler: @escaping (AirshipWorkRequest) async throws ->
            AirshipWorkResult
    ) {
        self.workID = workID
        self.conditionsMonitor = conditionsMonitor
        self.rateLimiter = rateLimiter
        self.backgroundTasks = backgroundTasks
        self.workHandler = workHandler

        (self.workStream, self.workContinuation) = AsyncStream<PendingRequest>.airshipMakeStreamWithContinuation()
    }

    deinit {
        workContinuation.finish()
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
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

        case .keepIfNotStarted:
            queueWork = Set(pending).subtracting(inProgress).isEmpty
        }

        if queueWork {
            let pendingID = nextPendingID
            nextPendingID += 1
            let pendingRequest = PendingRequest(id: pendingID, request: request)
            pending.append(pendingRequest)
            workContinuation.yield(pendingRequest)
        }
    }

    func run() async {
        for await next in self.workStream {
            let task: Task<Void, any Error> = Task { [weak self] in
                var attempt = 1
                while await self?.isValidRequest(next) == true {
                    let cancellableValueHolder: CancellableValueHolder<Task<Void, any Error>> = CancellableValueHolder { task in
                        task.cancel()
                    }

                    await withTaskCancellationHandler { [attempt] in
                        let task = Task { [weak self] in
                            try Task.checkCancellation()
                            try await self?.process(
                                pendingRequest: next,
                                attempt: attempt
                            ) {
                                cancellableValueHolder.cancel()
                            }
                        }

                        cancellableValueHolder.value = task
                        try? await task.result.get()
                    } onCancel: {
                        cancellableValueHolder.cancel()
                    }
                    attempt += 1
                }
            }

            tasks.insert(task)
            try? await task.result.get()
            tasks.remove(task)
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
        onCancel: @escaping @Sendable () -> Void
    ) async throws {
        let canonicalID = "\(workID)(\(pendingRequest.id))"
        try await prepare(pendingRequest: pendingRequest)
        try Task.checkCancellation()

        let backgroundTask = try await backgroundTasks.beginTask("Airship: \(canonicalID)") {
            onCancel()
        }

        var result: AirshipWorkResult = .failure

        inProgress.insert(pendingRequest)
        do {
            result = try await self.workHandler(pendingRequest.request)
        } catch {
            AirshipLogger.debug("Failed to execute work \(canonicalID): \(error)")
        }
        inProgress.remove(pendingRequest)

        if result == .success {
            // Success
            AirshipLogger.trace("Work \(canonicalID) finished")
            self.removeRequest(pendingRequest)
            backgroundTask.cancel()
        } else {
            AirshipLogger.trace("Work \(canonicalID) failed")
            backgroundTask.cancel()
            try Task.checkCancellation()
            let backOff = min(
                Worker.maxBackOff,
                Double(attempt) * Worker.initialBackOff
            )

            AirshipLogger.trace("Work \(canonicalID) backing off for \(backOff) seconds.")
            let cancellable = self.notificationCenter
                .publisher(
                    for: AppStateTracker.didEnterBackgroundNotification
                )
                .first()
                .sink { _ in
                    onCancel()
                }

            try await Self.sleep(backOff)
            cancellable.cancel()
        }
    }

    func calculateBackgroundWaitTime(
        maxTime: TimeInterval
    ) async -> TimeInterval {
        guard let pending = self.pending.first else {
            return 0.0
        }

        return await calculateBackgroundWaitTime(
            workRequest: pending.request,
            maxTime: maxTime
        )
    }


    private func calculateBackgroundWaitTime(
        workRequest: AirshipWorkRequest,
        maxTime: TimeInterval
    ) async -> TimeInterval {
        guard
            await self.conditionsMonitor.checkConditions(
                workRequest: workRequest
            ),
            let rateLimitIDs = workRequest.rateLimitIDs,
            !rateLimitIDs.isEmpty
        else {
            return 0.0
        }

        let wait = await self.rateLimiter.nextAvailable(rateLimitIDs)

        if wait > maxTime {
            return 0.0
        }
        return wait
    }

    private func prepare(pendingRequest: PendingRequest) async throws {
        let workRequest = pendingRequest.request

        if workRequest.initialDelay > 0 {
            let timeSinceRequest = Date().timeIntervalSince(pendingRequest.date)
            if timeSinceRequest < workRequest.initialDelay {
                try await Self.sleep(workRequest.initialDelay - timeSinceRequest)
            }
        }

        guard let rateLimitIDs = workRequest.rateLimitIDs, !rateLimitIDs.isEmpty else {
            await self.conditionsMonitor.awaitConditions(
                workRequest: workRequest
            )
            return
        }

        repeat {
            let rateLimit = await rateLimiter.nextAvailable(
                rateLimitIDs
            )
            if rateLimit > 0 {
                try await Self.sleep(rateLimit)
            }
            await self.conditionsMonitor.awaitConditions(
                workRequest: workRequest
            )
        } while await !rateLimiter.trackIfWithinLimit(rateLimitIDs)
    }

    private static func sleep(_ time: TimeInterval) async throws {
        guard time > 0 else { return }
        let sleep = UInt64(time * 1_000_000_000)
        try await Task.sleep(nanoseconds: sleep)
    }

    fileprivate struct PendingRequest: Equatable, Sendable, Hashable {
        let id: Int
        let request: AirshipWorkRequest
        let date: Date = Date()
    }
}
