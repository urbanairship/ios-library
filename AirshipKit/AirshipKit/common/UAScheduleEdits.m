/* Copyright Urban Airship and Contributors */

#import "UAScheduleEdits+Internal.h"
#import "UAScheduleInfo+Internal.h"
#import "UAUtils+Internal.h"

NSString * const UAScheduleEditsErrorDomain = @"com.urbanairship.schedule_edits";

@implementation UAScheduleEditsBuilder

- (BOOL)applyFromJson:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                          code:UAScheduleEditsErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    // Priority
    id priority = json[UAScheduleInfoPriorityKey];
    if (priority && ![priority isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Priority must be defined and be a number. Invalid value: %@", priority];
            *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                          code:UAScheduleEditsErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    // Limit
    id limit = json[UAScheduleInfoLimitKey];
    if (limit && ![limit isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Limit must be defined and be a number. Invalid value: %@", limit];
            *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                          code:UAScheduleEditsErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    // Start
    NSDate *start;
    if (json[UAScheduleInfoStartKey]) {
        if (![json[UAScheduleInfoStartKey] isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Start must be ISO 8601 timestamp. Invalid value: %@", start];
                *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                              code:UAScheduleEditsErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        start = [UAUtils parseISO8601DateFromString:json[UAScheduleInfoStartKey]];
    }

    // End
    NSDate *end;
    if (json[UAScheduleInfoEndKey]) {
        if (![json[UAScheduleInfoEndKey] isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"End must be ISO 8601 timestamp. Invalid value: %@", end];
                *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                              code:UAScheduleEditsErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        end = [UAUtils parseISO8601DateFromString:json[UAScheduleInfoEndKey]];
    }

    // Group
    id group = json[UAScheduleInfoGroupKey];
    if (group && ![group isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Group must be a string. Invalid value: %@", group];
            *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                          code:UAScheduleEditsErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    // Interval
    id interval = json[UAScheduleInfoIntervalKey];
    if (interval && ![interval isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Interval must be a number. Invalid value: %@", json[UAScheduleInfoIntervalKey]];
            *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                          code:UAScheduleEditsErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    // Edit Grace Period
    NSNumber *editGracePeriod;
    if (json[UAScheduleInfoEditGracePeriodKey]) {
        if (![json[UAScheduleInfoEditGracePeriodKey] isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Edit grace period must be a number. Invalid value: %@", json[UAScheduleInfoEditGracePeriodKey]];
                *error =  [NSError errorWithDomain:UAScheduleEditsErrorDomain
                                              code:UAScheduleEditsErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return NO;
        }

        editGracePeriod = @([json[UAScheduleInfoEditGracePeriodKey] doubleValue] * 24 * 60 * 60);
    }

    self.limit = limit;
    self.start = start;
    self.end = end;
    self.interval = interval;
    self.priority = priority;
    self.editGracePeriod = editGracePeriod;

    return YES;
}

@end

@implementation UAScheduleEdits

- (instancetype)initWithBuilder:(UAScheduleEditsBuilder *)builder {
    self = [super init];
    if (self) {
        self.data = builder.data;
        self.priority = builder.priority;
        self.limit = builder.limit;
        self.start = builder.start;
        self.end = builder.end;
        self.editGracePeriod = builder.editGracePeriod;
        self.interval = builder.interval;
    }

    return self;
}

@end


