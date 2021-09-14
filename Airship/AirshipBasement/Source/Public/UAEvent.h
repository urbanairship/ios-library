/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible priorities for an event.
 * @note For internal use only. :nodoc:
 */
typedef NS_ENUM(NSInteger, UAEventPriority) {
    /**
     * Low priority event. When added in the background, it will not schedule a send
     * if the last send was within 15 mins. Adding in the foreground will schedule
     * sends normally.
     */
    UAEventPriorityLow,

    /**
     * Normal priority event. Sends will be scheduled based on the batching time.
     */
    UAEventPriorityNormal,

    /**
     * High priority event. A send will be scheduled immediately.
     */
    UAEventPriorityHigh
} NS_SWIFT_NAME(EventPriority);


/**
 * Defines an Airship event.
 */
NS_SWIFT_NAME(Event)
@protocol UAEvent <NSObject>

@required

/**
 * The event's data.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) NSDictionary *data;

/**
 * The event's type.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) NSString *eventType;

/**
 * The event's priority.
 * @note For internal use only. :nodoc:
 */
@property (nonatomic, readonly) UAEventPriority priority;

@optional

/**
 * Checks if the event is valid. Invalid events will be dropped.
 * @return YES if the event is valid.
 */ 
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
