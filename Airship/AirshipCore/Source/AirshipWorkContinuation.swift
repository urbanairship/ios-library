/* Copyright Airship and Contributors */

import Foundation

public class AirshipWorkContinuation: @unchecked Sendable {

    private var isCancelled = false
    private var isCompleted = false
    private var onTaskFinished: (AirshipWorkResult) -> Void
    private let lock = AirshipLock()

    public init(onTaskFinished: @escaping (AirshipWorkResult) -> Void) {
        self.onTaskFinished = onTaskFinished
    }

    public func cancel() {
        lock.sync {
            guard !isCompleted && !self.isCancelled else {
                return
            }

            self.isCancelled = true
        }
    }

    public func finishTask(_ result: AirshipWorkResult) {
        lock.sync {
            guard !isCompleted else {
                return
            }

            self.isCompleted = true
            self.onTaskFinished(result)
        }
    }
}
