/* Copyright Airship and Contributors */

#import "UAScheduleDataMigrator+Internal.h"
#import "UAGlobal.h"
#import "NSJSONSerialization+UAAdditions.h"

// These constants are re-defined here to keep them isolated from
// any changes in the IAM payload definitions.
NSString *const UAInAppMessageV2DisplayTypeKey = @"display_type";
NSString *const UAInAppMessageV2DisplayContentKey = @"display";
NSString *const UAInAppMessageV2DisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageV2DurationKey = @"duration";

NSString *const UAInAppMessageV2SourceKey = @"source";
NSString *const UAInAppMessageV2SourceAppDefinedValue = @"app-defined";
NSString *const UAInAppMessageV2SourceRemoteDataValue = @"remote-data";

@implementation UAScheduleDataMigrator

+ (void)migrateScheduleData:(UAScheduleData *)scheduleData
                 oldVersion:(NSUInteger)oldVersion
                 newVersion:(NSUInteger)newVersion {

    for (NSUInteger version = oldVersion; version < newVersion; version++) {
        switch (version) {
            case 0:
                [self perform0To1MigrationForScheduleData:scheduleData];
                break;
            case 1:
                [self perform1To2MigrationForScheduleData:scheduleData];
                break;
            default:
                UA_LERR(@"No migration available for version %lu to version %lu", (unsigned long)version, (unsigned long)(version + 1));
                break;
        }
    }

    UA_LTRACE(@"Migrated schedule data from %ld to %ld", (unsigned long)oldVersion, (unsigned long)newVersion);
}

// migrate duration from milliseconds to seconds
+ (void)perform0To1MigrationForScheduleData:(UAScheduleData *)scheduleData {
    scheduleData.dataVersion = @(1);

    // convert schedule data to a JSON dictionary
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

// some remote-data schedules had their source field set incorrectly to app-defined by faulty edit code
// this code migrates all app-defined sources to remote-data
+ (void)perform1To2MigrationForScheduleData:(UAScheduleData *)scheduleData {
    scheduleData.dataVersion = @(2);

    // convert schedule data to a JSON dictionary
    NSMutableDictionary *json = [[NSJSONSerialization objectWithString:scheduleData.data] mutableCopy];
    
    // only change if source is app-defined
    NSString *source = json[UAInAppMessageV2SourceKey];
    if (!source || ![source isEqualToString:UAInAppMessageV2SourceAppDefinedValue]) {
        // Not a UAInAppMessage or not app-defined source. No migration needed.
        return;
    }
    
    // change source to remote-data
    json[UAInAppMessageV2SourceKey] = UAInAppMessageV2SourceRemoteDataValue;

    // serialize the migrated data
    scheduleData.data = [NSJSONSerialization stringWithObject:json];
}

@end
