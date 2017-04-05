/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN


@class UAScheduleDelayData;
@class UAScheduleTriggerData;

@interface UAActionScheduleData : NSManagedObject

@property (nullable, nonatomic, retain) NSString *identifier;
@property (nullable, nonatomic, retain) NSString *group;
@property (nullable, nonatomic, retain) NSNumber *limit;
@property (nullable, nonatomic, retain) NSNumber *triggeredCount;
@property (nullable, nonatomic, retain) NSString *actions;
@property (nullable, nonatomic, retain) NSSet<UAScheduleTriggerData *> *triggers;
@property (nullable, nonatomic, retain) NSDate *start;
@property (nullable, nonatomic, retain) NSDate *end;
@property (nullable, nonatomic, retain) UAScheduleDelayData *delay;
@property (nullable, nonatomic, retain) NSNumber *isPendingExecution;
@property (nullable, nonatomic, retain) NSDate *delayedExecutionDate;

@end

NS_ASSUME_NONNULL_END
