import Foundation

/// - Note: For internal use only. :nodoc:
public struct AirshipNotificationCenter: @unchecked Sendable {

    public static let shared = AirshipNotificationCenter()

    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = NotificationCenter.default) {
        self.notificationCenter = notificationCenter
    }

    public func post(name: NSNotification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil){
        self.notificationCenter.post(
            name: name,
            object: object,
            userInfo: userInfo
        )
    }

    public func addObserver(
        forName: NSNotification.Name,
        object: Any? = nil,
        queue: OperationQueue? = nil,
        using: @escaping (Notification) -> Void
    ) {
        self.notificationCenter.addObserver(
            forName: forName,
            object: object,
            queue: queue,
            using: using
        )
    }


    public func postOnMain(name: NSNotification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil){
        UADispatcher.main.dispatchAsyncIfNecessary {
            self.post(
                name: name,
                object: object,
                userInfo: userInfo
            )
        }
    }


    public func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name, object: Any? = nil) {
        notificationCenter.addObserver(observer, selector: selector, name: name, object: object)
    }
    
}
