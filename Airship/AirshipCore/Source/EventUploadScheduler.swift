import Foundation

protocol EventUploadSchedulerProtocol: Sendable {
    func scheduleUpload(
        eventPriority: AirshipEventPriority,
        minBatchInterval: TimeInterval
    ) async

    func setWorkBlock(
        _ workBlock: @Sendable @escaping () async throws -> AirshipWorkResult
    ) async
}

actor EventUploadScheduler: EventUploadSchedulerProtocol {
    private static let foregroundWorkBatchDelay: TimeInterval = 5
    private static let backgroundWorkBatchDelay: TimeInterval = 1
    private static let uploadScheduleDelay: TimeInterval = 15
    private static let workID = "EventUploadScheduler.upload"

    private var lastWorkDate: Date = .distantPast
    private var nextScheduleDate: Date = .distantFuture
    private var isScheduled: Bool = false
    private var workBlock: (() async throws -> AirshipWorkResult)?

    private let workManager: AirshipWorkManagerProtocol
    private let appStateTracker: AppStateTrackerProtocol
    private let date: AirshipDateProtocol
    private let taskSleeper: AirshipTaskSleeper

    @MainActor
    init(
        appStateTracker: AppStateTrackerProtocol? = nil,
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        date: AirshipDateProtocol = AirshipDate.shared,
        taskSleeper: AirshipTaskSleeper = DefaultAirshipTaskSleeper.shared
    ) {
        self.appStateTracker = appStateTracker ?? AppStateTracker.shared
        self.workManager = workManager
        self.date = date
        self.taskSleeper = taskSleeper

        self.workManager.registerWorker(
            EventUploadScheduler.workID,
            type: .serial
        ) { [weak self] _ in
            guard let self else {
                return .success
            }
            return try await self.performWork()
        }
    }

    private func performWork() async throws -> AirshipWorkResult {
        self.lastWorkDate = self.date.now
        self.isScheduled = false

        var batchDelay = EventUploadScheduler.backgroundWorkBatchDelay
        if (await self.appStateTracker.state == .active) {
            batchDelay = EventUploadScheduler.foregroundWorkBatchDelay
        }
        
        try await self.taskSleeper.sleep(timeInterval: batchDelay)

        guard let workBlock = self.workBlock else {
            return .success
        }
        try Task.checkCancellation()
        return try await workBlock()
    }

    func scheduleUpload(
        eventPriority: AirshipEventPriority,
        minBatchInterval: TimeInterval
    ) async {
        let delay = await self.calculateNextUploadDelay(
            eventPriority: eventPriority,
            minBatchInterval: minBatchInterval
        )

        let proposedScheduleDate = self.date.now.advanced(by: delay)
        guard !self.isScheduled || self.nextScheduleDate >= proposedScheduleDate else {
            AirshipLogger.trace(
                "Upload already scheduled for an earlier time."
            )
            return
        }

        self.nextScheduleDate = proposedScheduleDate
        self.isScheduled = true
        self.workManager.dispatchWorkRequest(
            AirshipWorkRequest(
                workID: EventUploadScheduler.workID,
                initialDelay: delay,
                requiresNetwork: true,
                conflictPolicy: .replace
            )
        )
    }

    private func calculateNextUploadDelay(
        eventPriority: AirshipEventPriority,
        minBatchInterval: TimeInterval
    ) async -> TimeInterval {

        switch(eventPriority) {
        case .high:
            return 0
        case .normal: fallthrough
        default:
            if await self.appStateTracker.state == .background {
                return 0
            } else {
                var delay: TimeInterval = 0
                let timeSincelastSend = self.date.now.timeIntervalSince(self.lastWorkDate)
                if timeSincelastSend < minBatchInterval {
                    delay = minBatchInterval - timeSincelastSend
                }
                return max(delay, EventUploadScheduler.uploadScheduleDelay)
            }
        }
    }

    func setWorkBlock(
        _ workBlock: @Sendable @escaping () async throws -> AirshipWorkResult
    ) {
        self.workBlock = workBlock
    }
}
