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


@end

NS_ASSUME_NONNULL_END
