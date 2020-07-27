/* Copyright Airship and Contributors */

#import "UAScheduleDataMigrator+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UASchedule.h"

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

+ (void)migrateScheduleData:(UAScheduleData *)scheduleData {

    int oldVersion = [scheduleData.dataVersion intValue];

    switch (oldVersion) {
        case 0:
            [self perform0To1MigrationForScheduleData:scheduleData];
        case 1:
            [self perform1To2MigrationForScheduleData:scheduleData];
        case 2:
            [self perform2To3MigrationForScheduleData:scheduleData];
            break;
    }

    UA_LTRACE(@"Migrated schedule data from %ld to %ld", (unsigned long)oldVersion, (unsigned long)UAScheduleDataVersion);
    scheduleData.dataVersion = @(UAScheduleDataVersion);
}

// migrate duration from milliseconds to seconds
+ (void)perform0To1MigrationForScheduleData:(UAScheduleData *)scheduleData {
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

// move scheduleData.message.audience to scheduleData.audience
// use group as schedule ID if not app-defined
// set the schedule type
+ (void)perform2To3MigrationForScheduleData:(UAScheduleData *)scheduleData {
    NSMutableDictionary *json = [[NSJSONSerialization objectWithString:scheduleData.data] mutableCopy];

    if (json[@"display_type"] && json[@"display"]) {
        scheduleData.type = @(UAScheduleTypeInAppMessage);

        // Move audience to schedule
        id audience = json[@"audience"];
        if (audience) {
            scheduleData.audience = [NSJSONSerialization stringWithObject:audience];
            [json removeObjectForKey:@"audience"];
        }

        // If source is not app defined, set the group as the ID
        NSString *source = json[@"source"];
        if (source && ![source isEqualToString:@"app-defined"] && scheduleData.group) {
            scheduleData.identifier = scheduleData.group;
        }

        scheduleData.data = [NSJSONSerialization stringWithObject:json];
    } else {
        scheduleData.type = @(UAScheduleTypeActions);
    }
}

@end
