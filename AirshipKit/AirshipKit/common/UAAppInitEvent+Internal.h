/* Copyright 2010-2019 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAEvent.h"
#import "UAUserData.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Event when app is initialized.
 */
@interface UAAppInitEvent : UAEvent

///---------------------------------------------------------------------------------------
/// @name App Init Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UAAppInitEvent.
 *
 * @param userData The current inbox user data.
 */
+ (instancetype)event:(UAUserData *)userData;

/**
 * Factory method to create a UAAppInitEvent.
 */
+ (instancetype)event;

/**
 * Gathers the event data into a dictionary
 *
 * @param userData The current inbox user data.
 */
- (NSMutableDictionary *)gatherData:(UAUserData *)userData;

@end

NS_ASSUME_NONNULL_END
