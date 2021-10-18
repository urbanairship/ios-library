/* Copyright Airship and Contributors */

#import "UAScheduleDataMigrator+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UASchedule+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
// These constants are re-defined here to keep them isolated from
// any changes in the IAM payload definitions.
NSString *const UAInAppMessageV2DisplayTypeKey = @"display_type";
NSString *const UAInAppMessageV2DisplayContentKey = @"display";
NSString *const UAInAppMessageV2DisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageV2DurationKey = @"duration";

NSString *const UAInAppMessageV2SourceKey = @"source";
NSString *const UAInAppMessageV2SourceAppDefinedValue = @"app-defined";
NSString *const UAInAppMessageV2SourceRemoteDataValue = @"remote-data";

NSString *const UAScheduleMetadataOriginalScheduleIDKey = @"com.urbanairship.original_schedule_id";
NSString *const UAScheduleMetadataOriginalMessageIDKey = @"com.urbanairship.original_message_id";

@implementation UAScheduleDataMigrator

+ (void)migrateSchedules:(NSArray<UAScheduleData *> *)schedules {

    NSMutableArray *migratedScheduleIDs = [NSMutableArray array];

    for (UAScheduleData *scheduleData in schedules) {
        int oldVersion = [scheduleData.dataVersion intValue];

        switch (oldVersion) {
            case 0:
                [self perform0To1MigrationForScheduleData:scheduleData];
            case 1:
                [self perform1To2MigrationForScheduleData:scheduleData];
            case 2:
                [self perform2To3MigrationForScheduleData:scheduleData migratedScheduleIDs:migratedScheduleIDs];
                break;
        }

        if (scheduleData.identifier){
            [migratedScheduleIDs addObject:scheduleData.identifier];
        }

        UA_LTRACE(@"Migrated schedule data from %ld to %ld", (unsigned long)oldVersion, (unsigned long)UAScheduleDataVersion);
        scheduleData.dataVersion = @(UAScheduleDataVersion);
    }
}

// migrate duration from milliseconds to seconds
+ (void)perform0To1MigrationForScheduleData:(UAScheduleData *)scheduleData {
    // convert schedule data to a JSON dictionary
    NSMutableDictionary *json = [UAJSONUtils objectWithString:scheduleData.data options:NSJSONReadingMutableContainers error:nil];
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
    scheduleData.data = [UAJSONUtils stringWithObject:json];
}

// some remote-data schedules had their source field set incorrectly to app-defined by faulty edit code
// this code migrates all app-defined sources to remote-data
+ (void)perform1To2MigrationForScheduleData:(UAScheduleData *)scheduleData {
    // convert schedule data to a JSON dictionary
    NSMutableDictionary *json = [UAJSONUtils objectWithString:scheduleData.data
                                                      options:NSJSONReadingMutableContainers
                                                        error:nil];
    
    // only change if source is app-defined
    NSString *source = json[UAInAppMessageV2SourceKey];
    if (!source || ![source isEqualToString:UAInAppMessageV2SourceAppDefinedValue]) {
        // Not a UAInAppMessage or not app-defined source. No migration needed.
        return;
    }
    
    // change source to remote-data
    json[UAInAppMessageV2SourceKey] = UAInAppMessageV2SourceRemoteDataValue;

    // serialize the migrated data
    scheduleData.data = [UAJSONUtils stringWithObject:json];
}

// move scheduleData.message.audience to scheduleData.audience
// use message ID as schedule ID
// set the schedule type
+ (void)perform2To3MigrationForScheduleData:(UAScheduleData *)scheduleData
                        migratedScheduleIDs:(NSMutableArray<NSString *> *)migratedScheduleIDs  {

    NSMutableDictionary *json = [UAJSONUtils objectWithString:scheduleData.data
                                                      options:NSJSONReadingMutableContainers
                                                        error:nil];
    if (json[@"display_type"] && json[@"display"]) {
        scheduleData.type = @(UAScheduleTypeInAppMessage);

        // Move audience to schedule
        id audience = json[@"audience"];
        if (audience) {
            scheduleData.audience = [UAJSONUtils stringWithObject:audience];
            [json removeObjectForKey:@"audience"];
        }

        // If source is not app defined, set the group (message ID) as the ID
        NSString *source = json[@"source"];
        if (source && scheduleData.group) {
            NSString *originalMessageID = scheduleData.group;
            NSString *originalScheduleID = scheduleData.identifier;

            if([source isEqualToString:@"app-defined"]) {
                scheduleData.identifier = [self generateUniqueID:originalMessageID identifiers:migratedScheduleIDs];
                NSMutableDictionary *metadata = [NSMutableDictionary dictionary];

                if (scheduleData.metadata) {
                    [metadata addEntriesFromDictionary:[UAJSONUtils objectWithString:scheduleData.metadata]];
                }

                [metadata setValue:originalScheduleID forKey:UAScheduleMetadataOriginalScheduleIDKey];
                [metadata setValue:originalMessageID forKey:UAScheduleMetadataOriginalMessageIDKey];
                scheduleData.metadata = [UAJSONUtils stringWithObject:metadata];
            } else {
                scheduleData.identifier = originalMessageID;
            }
        }
        scheduleData.data = [UAJSONUtils stringWithObject:json];
    } else {
        scheduleData.type = @(UAScheduleTypeActions);
    }
}

+ (NSString *)generateUniqueID:(NSString *)identifier identifiers:(NSArray<NSString *> *)identifiers {
    NSString *unique = identifier;
    NSUInteger i = 0;
    while ([identifiers containsObject:unique]) {
        i++;
        unique = [NSString stringWithFormat:@"%@#%lu", identifier, i];
    }
    return unique;
}

@end
