/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible priorities for an event.
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
};


/**
 * This base class encapsulates analytics events.
 */
@interface UAEvent : NSObject

///---------------------------------------------------------------------------------------
/// @name Event Properties
///---------------------------------------------------------------------------------------

/**
 * The time the event was created.
 */
@property (nonatomic, readonly, copy) NSString *time;

/**
 * The unique event ID.
 */
@property (nonatomic, readonly, copy) NSString *eventID;

/**
 * The event's data.
 */
@property (nonatomic, readonly, strong) NSDictionary *data;

/**
 * The event's type.
 */
@property (nonatomic, readonly) NSString *eventType;

/**
 * The event's priority.
 */
@property (nonatomic, readonly) UAEventPriority priority;

///---------------------------------------------------------------------------------------
/// @name Event Validation
///---------------------------------------------------------------------------------------

/**
 * Checks if the event is valid. Invalid events will be dropped.
 * @return YES if the event is valid.
 */
- (BOOL)isValid;

@end

NS_ASSUME_NONNULL_END
