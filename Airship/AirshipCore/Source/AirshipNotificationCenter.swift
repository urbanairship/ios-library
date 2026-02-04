/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public struct AirshipNotificationCenter: Sendable {

    public static let shared: AirshipNotificationCenter = AirshipNotificationCenter()
    
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
    
    @discardableResult
    public func addObserver(
        forName: NSNotification.Name,
        object: (any Sendable)? = nil,
        queue: OperationQueue? = nil,
        using: @Sendable @escaping (Notification) -> Void
    ) -> AnyObject {
        return self.notificationCenter.addObserver(
            forName: forName,
            object: object,
            queue: queue,
            using: using
        )
    }
    
    public func postOnMain(name: NSNotification.Name, object: (any Sendable)? = nil, userInfo: [AnyHashable: Any]? = nil){
        let wrapped = try? AirshipJSON.wrap(userInfo)
        
        DefaultDispatcher.main.dispatchAsyncIfNecessary {
            self.post(
                name: name,
                object: object,
                userInfo: wrapped?.unWrap() as? [AnyHashable: Any]
            )
        }
    }
    
    public func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name, object: Any? = nil) {
        notificationCenter.addObserver(observer, selector: selector, name: name, object: object)
    }
    
    public func removeObserver(_ observer: Any) {
        notificationCenter.removeObserver(observer)
    }
}
