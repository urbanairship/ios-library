/* Copyright Airship and Contributors */

public import Foundation

public import UserNotifications

#if canImport(AirshipCore)
import AirshipCore
#endif

@objc
public final class UANotificationCategories: NSObject, Sendable {
    
    /**
     * Factory method to create the default set of user notification categories.
     * Background user notification actions will default to requiring authorization.
     * - Returns: A set of user notification categories
     */
    @objc
    public class func defaultCategories() -> Set<UNNotificationCategory> {
        return NotificationCategories.defaultCategories()
    }
    
}
