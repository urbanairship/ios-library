/* Copyright Airship and Contributors */



actor AirshipAsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func withPermit<T: Sendable>(block: @Sendable () async throws -> T) async throws -> T {
        await self.wait()
        defer {
            signal()
        }
        return try await block()
    }

    private func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    private func signal() {
        if let first = waiters.first {
            waiters.removeFirst()
            first.resume()
        } else {
            value += 1
        }
    }
}
