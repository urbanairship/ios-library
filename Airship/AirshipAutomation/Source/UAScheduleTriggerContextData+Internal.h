/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UAScheduleData;

NS_ASSUME_NONNULL_BEGIN

/**
 * CoreData class representing the backing data for
 * a UAScheduleTriggerContextData.
 *
 * This class should not ordinarily be used directly.
*/
@interface UAScheduleTriggerContextData : NSManagedObject

//---------------------------------------------------------------------------------------
/// @name Schedule Trigger Context Properties
///---------------------------------------------------------------------------------------

/**
 * Trigger's goal.
 */
@property (nullable, nonatomic, retain) NSNumber *goal;

/**
 * Trigger's predicate.
 */
@property (nullable, nonatomic, retain) NSData *predicateData;

/**
 * Trigger type.
 */
@property (nullable, nonatomic, retain) NSNumber *type;
/**
 * Triggering event as JSON.
 */
@property(nullable, nonatomic, retain) NSString *event;

/**
 * The schedule data.
 */
@property (nullable, nonatomic, retain) UAScheduleData *schedule;


@end

NS_ASSUME_NONNULL_END
