/* Copyright Airship and Contributors */

public import Foundation
public import Combine

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
@MainActor
public final class AirshipObservableTimer: ObservableObject {
    private static let tick: TimeInterval = 0.1
    private var elapsedTime: TimeInterval = 0
    private let duration: TimeInterval?

    private var isStarted: Bool = false
    private var task: Task<Void, any Error>?
    private var taskSleeper: any AirshipTaskSleeper

    public var isPaused: Bool = false

    @Published
    public private(set) var isExpired: Bool = false

    public init(duration: TimeInterval?, taskSleeper: any AirshipTaskSleeper = .shared) {
        self.duration = duration
        self.taskSleeper = taskSleeper
    }

    private var nextTick: TimeInterval {
        guard let duration else { return Self.tick }
        // Round to millisecond precision to avoid floating-point accumulation
        let remaining = ((duration - elapsedTime) * 1000).rounded() / 1000
        return min(remaining, Self.tick)
    }

    public func onAppear() {
        guard !isStarted, !isExpired, let duration else { return }

        self.isStarted = true

        self.task = Task { @MainActor [weak self, taskSleeper] in
            while let self = self, !self.isExpired, self.isStarted {
                if self.isPaused {
                    try await taskSleeper.sleep(timeInterval: Self.tick)
                    continue
                }

                let sleepInterval = self.nextTick
                try await taskSleeper.sleep(timeInterval: sleepInterval)

                guard self.isStarted, !Task.isCancelled else { return }

                if !self.isPaused {
                    self.elapsedTime += sleepInterval
                    if self.elapsedTime >= duration {
                        self.isExpired = true
                        return
                    }
                }
            }
        }
    }

    public func onDisappear() {
        isStarted = false
        task?.cancel()
        task = nil
    }
}
