/* Copyright Airship and Contributors */

import Foundation

/// - Note: for internal use only.  :nodoc:
public protocol AirshipTimerProtocol: Sendable {
    @MainActor
    var time : TimeInterval { get }

    @MainActor
    func start()

    @MainActor
    func stop()
}

/// - Note: for internal use only.  :nodoc:
@MainActor
final public class AirshipTimer: AirshipTimerProtocol {
    private var isStarted: Bool = false
    private var elapsedTime: TimeInterval = 0
    private var startDate: Date? = nil
    private let date: any AirshipDateProtocol

    public init(date: any AirshipDateProtocol = AirshipDate.shared) {
        self.date = date
    }

    public func start() {
        guard !self.isStarted else { return }

        self.startDate = date.now
        self.isStarted = true
    }

    public func stop() {
        guard self.isStarted else { return }

        self.elapsedTime += currentSessionTime()
        self.startDate = nil
        self.isStarted = false
    }

    private func currentSessionTime() -> TimeInterval {
        guard let date = self.startDate else { return 0 }
        return self.date.now.timeIntervalSince(date)
    }

    public var time: TimeInterval {
        return self.elapsedTime + currentSessionTime()
    }

}

