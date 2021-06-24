/* Copyright Airship and Contributors */
import AirshipCore

class Entry {
    let time : TimeInterval
    let block : () -> Void

    init(time: TimeInterval, block: @escaping () -> Void) {
        self.time = time
        self.block = block
    }
}

@objc(UATestDispatcher)
public class TestDispatcher: UADispatcher {
    private var currentTime : TimeInterval  = 0
    private lazy var pending = [Entry]()

    @objc
    public init() {
        super.init(queue: DispatchQueue.main)
    }

    @objc
    public func advanceTime(_ time: TimeInterval) {
        currentTime += time
        let expired = pending.filter { $0.time <= currentTime }
        expired.forEach { $0.block() }
        pending.removeAll { (entry) in
            expired.contains { $0 === entry }
        }
    }

    public override func dispatchSync(_ block: @escaping () -> Void) {
        block()
    }

    public override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }

    public override func dispatch(after delay: TimeInterval, timebase: UADispatcherTimeBase, block: @escaping () -> Void) -> UADisposable {
        let entry = Entry(time: currentTime + Swift.max(delay, 0), block: block)
        self.pending.append(entry)
        return UADisposable() { [weak self] in
            self?.pending.removeAll { $0 === entry }
        }
    }
}
