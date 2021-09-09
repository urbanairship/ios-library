/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc(UAExpirableTask)
public class ExpirableTask : NSObject, Task {
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

    private let completionHandler: ((Bool) -> Void)
    private var isExpired = false
    private var isCompleted = false

    @objc
    public init(taskID: String,
         requestOptions: TaskRequestOptions,
         completionHandler: @escaping (Bool) -> Void) {

        self._taskID = taskID
        self._requestOptions = requestOptions
        self.completionHandler = completionHandler
    }

    @objc
    public func taskCompleted() {
        guard !isCompleted else {
            return
        }

        self.isCompleted = true
        self.expirationHandler = nil
        completionHandler(true)
    }

    @objc
    public func taskFailed() {
        guard !isCompleted else {
            return
        }

        self.isCompleted = true
        self._expirationHandler = nil
        completionHandler(false)
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
}
