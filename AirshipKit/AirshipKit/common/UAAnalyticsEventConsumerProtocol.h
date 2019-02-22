/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An internal protocol that provides event add updates.
 */
@protocol UAAnalyticsEventConsumerProtocol

@required

///---------------------------------------------------------------------------------------
/// @name Analytics Consumer Protocol Core Methods
///---------------------------------------------------------------------------------------

/**
 * Returns the last event to be added to analytics.
 *
 * @param event The UAEvent.
 */
- (void)eventAdded:(UAEvent *)event;

@end

NS_ASSUME_NONNULL_END
