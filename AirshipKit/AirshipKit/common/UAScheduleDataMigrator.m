/* Copyright Urban Airship and Contributors */

#import "UAScheduleDataMigrator+Internal.h"
#import "UAGlobal.h"
#import "NSJSONSerialization+UAAdditions.h"

// These constants are re-defined here to keep them isolated from
// any changes in the IAM payload definitions.
NSString *const UAInAppMessageV2DisplayTypeKey = @"display_type";
NSString *const UAInAppMessageV2DisplayContentKey = @"display";
NSString *const UAInAppMessageV2DisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageV2DurationKey = @"duration";

@implementation UAScheduleDataMigrator

+ (void)migrateScheduleData:(UAScheduleData *)scheduleData
                 oldVersion:(NSUInteger)oldVersion
                 newVersion:(NSUInteger)newVersion {

    scheduleData.dataVersion = @(newVersion);
    switch (oldVersion) {
        case 0:
            [self perfrom0To1MigrationForScheduleData:scheduleData];
    }

    UA_LTRACE(@"Migrated schedule data from %ld to %ld", (unsigned long)oldVersion, (unsigned long)newVersion);
}
+ (void)perfrom0To1MigrationForScheduleData:(UAScheduleData *)scheduleData {
    // convert source data to a JSON dictionary
    NSMutableDictionary *json = [[NSJSONSerialization objectWithString:scheduleData.data] mutableCopy];
    NSString *displayType = json[UAInAppMessageV2DisplayTypeKey];
    if (!displayType || ![displayType isEqualToString:UAInAppMessageV2DisplayTypeBannerValue]) {
        // Not a UAInAppMessage or not a banner IAM. No migration needed.
        return;
    }

    NSNumber *duration = json[UAInAppMessageV2DisplayContentKey][UAInAppMessageV2DurationKey];
    if (!duration) {
        // No duration to migrate
        return;
    }

    // convert the duration from milliseconds to seconds
    duration = [NSNumber numberWithDouble:[duration doubleValue] / 1000];
    json[UAInAppMessageV2DisplayContentKey][UAInAppMessageV2DurationKey] = duration;

    // serialize the migrated data
    scheduleData.data = [NSJSONSerialization stringWithObject:json];
}

@end
