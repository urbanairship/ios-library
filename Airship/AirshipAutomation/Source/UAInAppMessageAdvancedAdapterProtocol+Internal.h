/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppReporting+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@protocol UAInAppMessageAdvancedAdapterProtocol <UAInAppMessageAdapterProtocol>

/**
 * Displays the in-app message. The adapter is responsible for all IAA events.
 * @param scheduleID  The schedule ID.
 * @param onEvent A callback when an event is added.
 * @param onDismiss A callback when a view is dismissed.
 */
- (void)displayWithScheduleID:(NSString *)scheduleID
                      onEvent:(void (^)(UAInAppReporting *))onEvent
                    onDismiss:(void (^)(UAInAppMessageResolution *resolution))onDismiss;
@end

NS_ASSUME_NONNULL_END
