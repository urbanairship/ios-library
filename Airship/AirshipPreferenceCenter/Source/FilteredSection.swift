/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

struct FilteredSection {
    let section: Section
    let items: [Item]
    
    
    static func filterConfig(_ config: PreferenceCenterConfig) -> [FilteredSection] {
         return config.sections.compactMap{ section in
             if let conditions = section.conditions, !checkConditions(conditions) {
                 return nil
             }

             let items = section.items.filter { item in
                 if let conditions = item.conditions {
                     return checkConditions(conditions)
                 } else {
                     return true
                 }
             }
             
             return FilteredSection(section: section, items: items)
         }
    }
    
    private static func checkConditions(_ conditions: [Condition]) -> Bool {
        for condition in conditions {
            guard checkCondition(condition) else {
                return false
            }
        }
        return true
    }
    
    private static func checkCondition(_ condition: Condition) -> Bool {
        switch (condition.conditionType) {
        case .notificationOptIn:
            if let condition = condition as? NotificationOptInCondition {
                switch (condition.optInStatus) {
                case .optedIn:
                    return Airship.push.isPushNotificationsOptedIn
                case .optedOut:
                    return !Airship.push.isPushNotificationsOptedIn
                }
            }
        }
        return false
    }
}
