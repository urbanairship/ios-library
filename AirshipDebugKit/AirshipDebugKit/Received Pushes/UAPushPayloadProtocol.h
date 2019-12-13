/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPushPayload.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An internal protocol that provides event add updates.
 */
@protocol UAPushPayloadProtocol

@required

///---------------------------------------------------------------------------------------
/// @name Analytics Consumer Protocol Core Methods
///---------------------------------------------------------------------------------------

/**
 * Returns the last event to be added to analytics.
 *
 * @param event The UAEvent.
 */
- (void)pushAdded:(UAPushPayload *)push;

@end

NS_ASSUME_NONNULL_END
