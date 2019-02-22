/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UAScheduleData;
@class UAScheduleDelayConditionsData;
@class UAScheduleTriggerData;

NS_ASSUME_NONNULL_BEGIN

/**
 * CoreData class representing the backing data for
 * a UAScheduleDelayData.
 *
 * This class should not ordinarily be used directly.
 */
@interface UAScheduleDelayData : NSManagedObject

///---------------------------------------------------------------------------------------
/// @name Schedule Delay Data Internal Properties
///---------------------------------------------------------------------------------------

/**
 * Minimum amount of time to wait in seconds before the schedule actions are able to execute.
 */
@property (nullable, nonatomic, retain) NSNumber *seconds;

/**
 * A JSON encoded string of app screens that will trigger the schedule's actions if viewed.
 * Specifying screens requires the application to make use of UAAnalytic's screen tracking method `trackScreen:`.
 */
@property (nullable, nonatomic, copy) NSString *screens;

/**
 * Specifies the ID of a region that the device must currently be in before the schedule's
 * actions are able to be executed. Specifying regions requires the application to add UARegionEvents
 * to UAAnalytics.
 */
@property (nullable, nonatomic, retain) NSString *regionID;

/**
 * Specifies the app state that is required before the schedule's actions are able to execute.
 * Defaults to `UAScheduleDelayAppStateAny`.
 */
@property (nullable, nonatomic, retain) NSNumber *appState;

/**
 * The schedule data.
 */
@property (nullable, nonatomic, retain) UAScheduleData *schedule;

/**
 * The cancellation triggers.
 */
@property (nullable, nonatomic, retain) NSSet<UAScheduleTriggerData *> *cancellationTriggers;

@end

NS_ASSUME_NONNULL_END
