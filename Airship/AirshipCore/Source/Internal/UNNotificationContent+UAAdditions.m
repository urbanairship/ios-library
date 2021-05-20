/* Copyright Airship and Contributors */

#import "UNNotificationContent+UAAdditions.h"

@implementation UNNotificationContent (UAAdditions)

#if TARGET_OS_IOS
- (BOOL)isAirshipNotificationContent {
    NSDictionary *notificationInfo = self.userInfo;
    for (NSString *key in notificationInfo.allKeys) {
        if ([key hasPrefix:@"com.urbanairship"]) {
            return YES;
        }
    }
    return NO;
}
#endif

@end
