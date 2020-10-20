/* Copyright Airship and Contributors */

#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN


@interface UAEvent ()

///---------------------------------------------------------------------------------------
/// @name Event Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The time the event was created.
 */
@property (nonatomic, copy) NSString *time;

/**
 * The unique event ID.
 */
@property (nonatomic, copy) NSString *eventID;

/**
 * The JSON event size in bytes.
 */
@property (nonatomic, readonly) NSUInteger jsonEventSize;


///---------------------------------------------------------------------------------------
/// @name Event Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Gets the current enabled notification types as a string array.
 *
 * @return The current notification types as a string array.
 */
- (NSArray *)notificationTypes;

/**
 * Gets the current notification authorization as a string.
 *
 * @return The current notification authorization as a string.
 */
- (NSString *)notificationAuthorization;


@end

NS_ASSUME_NONNULL_END
