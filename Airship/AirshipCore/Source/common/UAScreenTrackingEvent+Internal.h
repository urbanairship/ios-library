/* Copyright Airship and Contributors */

#import "UAEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAScreenTrackingEvent : UAEvent

/**
 * The tracking event start time
 */
@property (nonatomic, readonly) NSTimeInterval startTime;

/**
 * The tracking event stop time
 */
@property (nonatomic, readonly) NSTimeInterval stopTime;

/**
 * The tracking event duration
 */
@property (nonatomic, readonly) NSTimeInterval duration;

/**
 * The name of the screen to be tracked
 */
@property (nonatomic, readonly) NSString *screen;

/**
 * The name of the previous tracked screen
 */
@property (nonatomic, nullable, readonly) NSString *previousScreen;

///---------------------------------------------------------------------------------------
/// @name Screen Tracking Event Internal Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UAScreenTrackingEvent with screen name and startTime
 */
+ (instancetype)eventWithScreen:(NSString *)screen
                 previousScreen:(nullable NSString *)screen
                      startTime:(NSTimeInterval)startTime
                       stopTime:(NSTimeInterval)stopTime;

@end

NS_ASSUME_NONNULL_END
