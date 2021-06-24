/* Copyright Airship and Contributors */

@testable
import AirshipChat
import AirshipCore

class Entry {
    let time : TimeInterval
    let block : () -> Void

    init(time: TimeInterval, block: @escaping () -> Void) {
        self.time = time
        self.block = block
    }
}

class MockDispatcher: UADispatcher {
    private var currentTime : TimeInterval  = 0
    private lazy var pending = [Entry]()

    public init() {
        super.init(queue: DispatchQueue.main)
    }

    public func advanceTime(_ time: TimeInterval) {
        currentTime += time
        pending.removeAll { (entry) -> Bool in
            let expired = entry.time <= currentTime

            if (expired) {
                entry.block()
            }
            return expired
        }
    }

    override func dispatchSync(_ block: @escaping () -> Void) {
        block()
    }

    override func dispatchAsync(_ block: @escaping () -> Void) {
        block()
    }

    override func dispatch(after delay: TimeInterval, block: @escaping () -> Void) -> UADisposable {
        guard delay > 0 else {
            block()
            return UADisposable()
        }

        let entry = Entry(time: currentTime + delay, block: block)
        self.pending.append(entry)
        return UADisposable() {
            self.pending = self.pending.filter { $0 !== entry }
        }
    }
}
