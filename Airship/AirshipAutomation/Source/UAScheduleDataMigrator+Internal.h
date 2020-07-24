/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schedule data migrator.
 */
@interface UAScheduleDataMigrator : NSObject

/**
 * Migrates the schedule data.
 * @param scheduleData The schedule data.
 */
+ (void)migrateScheduleData:(UAScheduleData *)scheduleData;

@end

NS_ASSUME_NONNULL_END
