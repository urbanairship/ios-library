/* Copyright Airship and Contributors */
import AirshipCore

class Entry {
    let time: TimeInterval
    let block: () -> Void

    init(time: TimeInterval, block: @escaping () -> Void) {
        self.time = time
        self.block = block
    }
}

@objc(UATestDispatcher)
public class TestDispatcher: UADispatcher {
    private var currentTime: TimeInterval = 0
    private lazy var pending = [Entry]()
    private let internalDispatcher = UADispatcher.serial(.default)

    @objc
    public init() {
        super.init(queue: DispatchQueue.main)
    }

    @objc
    public func advanceTime(_ time: TimeInterval) {
        internalDispatcher.doSync { [self] in
            self.currentTime += time
            let expired = self.pending.filter { $0.time <= self.currentTime }
            expired.forEach { $0.block() }
            self.pending.removeAll { (entry) in
                expired.contains { $0 === entry }
            }
        }
    }

    public override func dispatchSync(_ block: @escaping () -> Void) {
        block()
    }

    public override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }

    public override func dispatch(
        after delay: TimeInterval,
        timebase: DispatcherTimeBase,
        block: @escaping () -> Void
    ) -> Disposable {

        var disposable: Disposable? = nil
        self.internalDispatcher.doSync { [self] in
            let entry = Entry(
                time: self.currentTime + Swift.max(delay, 0),
                block: block
            )
            self.pending.append(entry)
            disposable = Disposable { [weak self] in
                self?.internalDispatcher
                    .doSync {
                        self?.pending.removeAll { $0 === entry }
                    }
            }
        }

        return disposable!
    }
}
