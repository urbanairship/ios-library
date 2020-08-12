/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schedule data migrator.
 */
@interface UAScheduleDataMigrator : NSObject

/**
 * Migrates the schedule datas.
 * @param schedules The array of schedule data to migrate.
 */
+ (void)migrateSchedules:(NSArray<UAScheduleData *> *)schedules;

@end

NS_ASSUME_NONNULL_END
