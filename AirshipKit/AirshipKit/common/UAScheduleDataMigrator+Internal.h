/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAScheduleData+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schedule data migrator.
 */
@interface UAScheduleDataMigrator : NSObject

/**
 * Migrates the schedule data.
 * @param oldVersion The old schedule data version.
 * @param newVersion The new schedule data version.
 */
+ (void)migrateScheduleData:(UAScheduleData *)scheduleData
                 oldVersion:(NSUInteger)oldVersion
                 newVersion:(NSUInteger)newVersion;

@end

NS_ASSUME_NONNULL_END
