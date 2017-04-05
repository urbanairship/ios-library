/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Event when app is initialized.
 */
@interface UAAppInitEvent : UAEvent

/**
 * Factory method to create a UAAppInitEvent.
 */
+ (instancetype)event;


/**
 * Gathers the event data into a dictionary
 */
- (NSMutableDictionary *)gatherData;

@end

NS_ASSUME_NONNULL_END
