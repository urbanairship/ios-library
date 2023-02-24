import Foundation

protocol EventUploadSchedulerProtocol: Sendable {
    func scheduleUpload(
        eventPriority: EventPriority,
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
    private let date: AirshipDate
    private let delayer: (TimeInterval) async throws -> Void

    init(
        appStateTracker: AppStateTrackerProtocol = AppStateTracker.shared,
        workManager: AirshipWorkManagerProtocol = AirshipWorkManager.shared,
        date: AirshipDate = AirshipDate(),
        delayer: ((TimeInterval) async throws -> Void)? = nil
    ) {
        self.appStateTracker = appStateTracker
        self.workManager = workManager
        self.date = date
        self.delayer = delayer ??  { time in
            try await Task.sleep(
                nanoseconds: UInt64(time * 1_000_000_000)
            )
        }

        self.workManager.registerWorker(
            EventUploadScheduler.workID,
            type: .serial
        ) { [weak self] _ in
            guard let self = self else {
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
        
        try await self.delayer(batchDelay)

        guard let workBlock = self.workBlock else {
            return .success
        }
        try Task.checkCancellation()
        return try await workBlock()
    }

    func scheduleUpload(
        eventPriority: EventPriority,
        minBatchInterval: TimeInterval
    ) async {
        let delay = await self.calculateNextUploadDelay(
            eventPriority: eventPriority,
            minBatchInterval: minBatchInterval
        )

        let proposedScheduleDate = self.date.now.addingTimeInterval(delay)
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
        eventPriority: EventPriority,
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
