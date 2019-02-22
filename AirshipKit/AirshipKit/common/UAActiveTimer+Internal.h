/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Times how long the app has been active.
 */
@interface UAActiveTimer : NSObject


/**
 * Total application active time.
 */
@property (nonatomic, readonly) NSTimeInterval time;

/**
 * Starts the timer.
 */
- (void)start;

/**
 * Stops the timer.
 */
- (void)stop;

@end
