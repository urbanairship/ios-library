/* Copyright Airship and Contributors */



/// - Note: for internal use only.  :nodoc:
public protocol AirshipTimerProtocol: Sendable {
    @MainActor
    var time : TimeInterval { get }

    @MainActor
    func start()

    @MainActor
    func stop()
}

@MainActor
final class AirshipTimer: AirshipTimerProtocol {
    private var isStarted: Bool = false
    private var elapsedTime: TimeInterval = 0
    private var startDate: Date? = nil
    private let date: any AirshipDateProtocol

    init(date: any AirshipDateProtocol = AirshipDate.shared) {
        self.date = date
    }

    func start() {
        guard !self.isStarted else { return }

        self.startDate = date.now
        self.isStarted = true
    }

    func stop() {
        guard self.isStarted else { return }

        self.elapsedTime += currentSessionTime()
        self.startDate = nil
        self.isStarted = false
    }

    private func currentSessionTime() -> TimeInterval {
        guard let date = self.startDate else { return 0 }
        return self.date.now.timeIntervalSince(date)
    }

    var time: TimeInterval {
        return self.elapsedTime + currentSessionTime()
    }

}

