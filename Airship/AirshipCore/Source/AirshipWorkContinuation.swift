import Foundation

@objc
public class AirshipWorkContinuation: NSObject {

    private var _cancellationHandler: (() -> Void)? = nil
    @objc
    public var cancellationHandler: (() -> Void)? {
        get {
            return _cancellationHandler
        }
        set {
            if isCancelled {
                newValue?()
                self._cancellationHandler = nil
            } else {
                self._cancellationHandler = newValue
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
            if isCompleted {
                newValue?()
                self._completionHandler = nil
            } else {
                self._completionHandler = newValue
            }
        }
    }

    private var isCancelled = false
    private var isCompleted = false
    private var onTaskFinished: (AirshipWorkResult) -> Void

    @objc
    public init(onTaskFinished: @escaping (AirshipWorkResult) -> Void) {
        self.onTaskFinished = onTaskFinished
    }

    @objc
    public func cancel() {
        guard !isCompleted && !self.isCancelled else {
            return
        }

        self.isCancelled = true

        if let handler = _cancellationHandler {
            handler()
            self._cancellationHandler = nil
        }
    }

    public func finishTask(_ result: AirshipWorkResult) {
        guard !isCompleted else {
            return
        }

        self.isCompleted = true
        self.cancellationHandler = nil
        self.completionHandler?()
        self.completionHandler = nil
        self.onTaskFinished(result)
    }
}
