/* Copyright Airship and Contributors */

import Foundation

class ExpirableTask: AirshipTask {
    private let _taskID : String
    @objc
    public var taskID: String {
        get {
            return self._taskID
        }
    }

    private let _requestOptions : TaskRequestOptions
    @objc
    public var requestOptions: TaskRequestOptions {
        get {
            return self._requestOptions
        }
    }

    private var _expirationHandler: (() -> Void)? = nil

    @objc
    public var expirationHandler: (() -> Void)? {
        get {
            return _expirationHandler
        }
        set {
            if (isExpired) {
                newValue?()
                self._expirationHandler = nil
            } else {
                self._expirationHandler = newValue
            }
        }
    }

    private var _completionHandler: (() -> Void)? = nil

    @objc
    public var completionHandler: (() -> Void)? {
        get {
            return _completionHandler
        }
        set {
            if (isCompleted) {
                newValue?()
                self._completionHandler = nil
            } else {
                self._completionHandler = newValue
            }
        }
    }

    private var isExpired = false
    private var isCompleted = false
    private var onTaskFinshed: (Bool) -> Void

    @objc
    public init(taskID: String,
                requestOptions: TaskRequestOptions,
                onTaskFinshed: @escaping (Bool) -> Void) {

        self._taskID = taskID
        self._requestOptions = requestOptions
        self.onTaskFinshed = onTaskFinshed
    }

    @objc
    public func taskCompleted() {
        finishTask(true)
    }

    @objc
    public func taskFailed() {
        finishTask(false)
    }

    @objc
    public func expire() {
        guard !isCompleted  && !self.isExpired else {
            return
        }

        self.isExpired = true

        if let handler = expirationHandler {
            handler()
            self._expirationHandler = nil
        } else {
            AirshipLogger.debug("Expiration handler not set, marking task as failed.")
            taskFailed()
        }
    }

    private func finishTask(_ result: Bool) {
        guard !isCompleted else {
            return
        }

        self.isCompleted = true
        self.expirationHandler = nil
        self.completionHandler?()
        self.completionHandler = nil
        self.onTaskFinshed(result)
    }
}
