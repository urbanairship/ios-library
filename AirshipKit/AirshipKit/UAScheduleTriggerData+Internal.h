/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class UAActionScheduleData;
@class UAScheduleDelayData;

NS_ASSUME_NONNULL_BEGIN

@interface UAScheduleTriggerData : NSManagedObject

@property (nullable, nonatomic, retain) NSNumber *goal;
@property (nullable, nonatomic, retain) NSNumber *goalProgress;
@property (nullable, nonatomic, retain) NSData *predicateData;
@property (nullable, nonatomic, retain) NSNumber *type;
@property (nullable, nonatomic, retain) UAActionScheduleData *schedule;
@property (nullable, nonatomic, retain) UAScheduleDelayData *delay;
@property (nullable, nonatomic, retain) NSDate *start;

@end

NS_ASSUME_NONNULL_END
