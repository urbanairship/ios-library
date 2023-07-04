/* Copyright Airship and Contributors */

#import "UAScheduleAudience+Internal.h"
#import "UATagSelector+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif


/// This class is no longer used internally except to parse the miss behavior. We are not able to remove it since its public and that would be a breaking change. We also
/// do not want to have to expose structs/enums from swfit to obj-c. For now, this class exists for public definitions of an audience and to parse
/// the miss behavior.

NSString * const UAScheduleAudienceNotificationOptInKey = @"notification_opt_in";
NSString * const UAScheduleAudienceLocationOptInKey = @"location_opt_in";
NSString * const UAScheduleAudienceLanguageTagsKey = @"locale";
NSString * const UATagSelectorKey = @"tags";
NSString * const UAScheduleAudienceAppVersionKey = @"app_version";
NSString * const UAScheduleAudienceMissBehaviorKey = @"miss_behavior";
NSString * const UAScheduleAudienceRequiresAnalytics = @"requires_analytics";
NSString * const UAScheduleAudiencePermissions = @"permissions";

NSString * const UAScheduleAudienceMissBehaviorCancelValue   = @"cancel";
NSString * const UAScheduleAudienceMissBehaviorSkipValue     = @"skip";
NSString * const UAScheduleAudienceMissBehaviorPenalizeValue = @"penalize";

NSString * const UAScheduleAudienceErrorDomain = @"com.urbanairship.in_app_message_audience";

@interface UAScheduleAudience()
@property(nonatomic, strong, nullable) NSNumber *notificationsOptIn;
@property(nonatomic, strong, nullable) NSNumber *locationOptIn;
@property(nonatomic, strong, nullable) NSArray<NSString *> *languageIDs;
@property(nonatomic, strong, nullable) UATagSelector *tagSelector;
@property(nonatomic, strong, nullable) UAJSONPredicate *versionPredicate;
@property(nonatomic, assign) UAScheduleAudienceMissBehaviorType missBehavior;
@property(nonatomic, strong, nullable) NSNumber *requiresAnalytics;
@property(nonatomic, strong, nullable) UAJSONPredicate *permissionPredicate;
@end

@implementation UAScheduleAudienceBuilder

// set default values for properties
- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.missBehavior = UAScheduleAudienceMissBehaviorPenalize;
    }
    
    return self;
}

- (BOOL)isValid {
    return YES;
}

@end

@implementation UAScheduleAudience

+ (UAScheduleAudienceMissBehaviorType)parseMissBehavior:(id)json error:(NSError **)error {
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        }
        return UAScheduleAudienceMissBehaviorPenalize;
    }

    /// Miss behavior
    id missBehaviorValue = json[UAScheduleAudienceMissBehaviorKey];
    if (missBehaviorValue) {
        if (![missBehaviorValue isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Miss behavior must be a string. Invalid value: %@", missBehaviorValue];
                *error =  [NSError errorWithDomain:UAScheduleAudienceErrorDomain
                                              code:UAScheduleAudienceErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return UAScheduleAudienceMissBehaviorSkip;
        } else {
            if ([UAScheduleAudienceMissBehaviorCancelValue isEqualToString:missBehaviorValue]) {
                return UAScheduleAudienceMissBehaviorCancel;
            } else if ([UAScheduleAudienceMissBehaviorSkipValue isEqualToString:missBehaviorValue]) {
                return UAScheduleAudienceMissBehaviorSkip;
            } else if ([UAScheduleAudienceMissBehaviorPenalizeValue isEqualToString:missBehaviorValue]) {
                return UAScheduleAudienceMissBehaviorPenalize;
            } else {
                if (error) {
                    NSString *msg = [NSString stringWithFormat:@"Invalid miss behavior: %@", missBehaviorValue];
                    *error =  [NSError errorWithDomain:UAScheduleAudienceErrorDomain
                                                  code:UAScheduleAudienceErrorCodeInvalidJSON
                                              userInfo:@{NSLocalizedDescriptionKey:msg}];
                }
                return UAScheduleAudienceMissBehaviorPenalize;
            }
        }
    }

    return UAScheduleAudienceMissBehaviorPenalize;
}

+ (nullable instancetype)audienceWithJSON:(id)json error:(NSError **)error {
    UAScheduleAudienceBuilder *builder = [[UAScheduleAudienceBuilder alloc] init];

    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        }
        return nil;
    }

    /// Notification Optin
    id notificationsOptIn = json[UAScheduleAudienceNotificationOptInKey];
    if (notificationsOptIn) {
        if (![notificationsOptIn isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAScheduleAudienceNotificationOptInKey, notificationsOptIn]];
            }
            return nil;
        }
        builder.notificationsOptIn = notificationsOptIn;
    }

    /// Location Optin
    id locationOptIn = json[UAScheduleAudienceLocationOptInKey];
    if (locationOptIn) {
        if (![locationOptIn isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAScheduleAudienceLocationOptInKey, locationOptIn]];
            }
            return nil;
        }
        builder.locationOptIn = locationOptIn;
    }

    /// Language tags
    id languageTags = json[UAScheduleAudienceLanguageTagsKey];
    if (languageTags) {
        if (![languageTags isKindOfClass:[NSArray class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be an array. Invalid value: %@", UAScheduleAudienceLanguageTagsKey, languageTags]];
            }
            return nil;
        }
        builder.languageTags = languageTags;
    }

    /// Tag selector
    id tagSelector = json[UATagSelectorKey];
    if (tagSelector) {
        builder.tagSelector = [UATagSelector selectorWithJSON:tagSelector error:error];
        if (!builder.tagSelector) {
            return nil;
        }
    }

    /// App version
    id versionPredicate = json[UAScheduleAudienceAppVersionKey];
    if (versionPredicate) {
        UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSON:versionPredicate error:error];
        builder.versionPredicate = predicate;
        if (!builder.versionPredicate) {
            return nil;
        }
    }

    
    /// Miss behavior
    NSError *missBehaviorError;
    builder.missBehavior = [self parseMissBehavior:json error:&missBehaviorError];
    if (missBehaviorError) {
        if (error) {
            *error = missBehaviorError;
        }
        return nil;
    }

    /// Requires analytics
    id requiresAnalyticsValue = json[UAScheduleAudienceRequiresAnalytics];
    if (requiresAnalyticsValue) {
        if(![requiresAnalyticsValue isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Require analytics must be a boolean. Invalid value: %@", requiresAnalyticsValue];
                *error =  [NSError errorWithDomain:UAScheduleAudienceErrorDomain
                                              code:UAScheduleAudienceErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        } else {
            builder.requiresAnalytics = requiresAnalyticsValue;
        }
    }
    
    /// Permissions
    id permissionPredicate = json[UAScheduleAudiencePermissions];
    if (permissionPredicate) {
        UAJSONPredicate *predicate = [[UAJSONPredicate alloc] initWithJSON:permissionPredicate error:error];
        if (!predicate) {
            return nil;
        }
        builder.permissionPredicate = predicate;
    }
    
    if (![builder isValid]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Invalid audience %@", json]];
        }

        return nil;
    }

    return [[UAScheduleAudience alloc] initWithBuilder:builder];
}

+ (NSError *)invalidJSONErrorWithMsg:(NSString *)msg {
    return [NSError errorWithDomain:UAScheduleAudienceErrorDomain
                               code:UAScheduleAudienceErrorCodeInvalidJSON
                           userInfo:@{NSLocalizedDescriptionKey:msg}];
}

+ (nullable instancetype)audienceWithBuilderBlock:(void(^)(UAScheduleAudienceBuilder *builder))builderBlock  {
    UAScheduleAudienceBuilder *builder = [[UAScheduleAudienceBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAScheduleAudience alloc] initWithBuilder:builder];
}

- (nullable instancetype)initWithBuilder:(UAScheduleAudienceBuilder *)builder {
    if (self = [super init]) {
        if (![builder isValid]) {
            UA_LERR(@"UAScheduleAudience could not be initialized, builder has missing or invalid parameters.");
            return nil;
        }

        self.notificationsOptIn = builder.notificationsOptIn;
        self.locationOptIn = builder.locationOptIn;
        self.languageIDs = builder.languageTags;
        self.tagSelector = builder.tagSelector;
        self.versionPredicate = builder.versionPredicate;
        self.missBehavior = builder.missBehavior;
        self.requiresAnalytics = builder.requiresAnalytics;
        self.permissionPredicate = builder.permissionPredicate;

    }
    return self;
}


#pragma mark - Validation


- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setValue:self.notificationsOptIn forKey:UAScheduleAudienceNotificationOptInKey];
    [json setValue:self.locationOptIn forKey:UAScheduleAudienceLocationOptInKey];
    [json setValue:self.languageIDs forKey:UAScheduleAudienceLanguageTagsKey];
    [json setValue:[self.tagSelector toJSON] forKey:UATagSelectorKey];
    [json setValue:self.versionPredicate.payload forKey:UAScheduleAudienceAppVersionKey];
    [json setValue:self.requiresAnalytics forKey:UAScheduleAudienceRequiresAnalytics];
    [json setValue:self.permissionPredicate.payload forKey:UAScheduleAudiencePermissions];
    
    switch (self.missBehavior) {
        case UAScheduleAudienceMissBehaviorCancel:
            [json setValue:UAScheduleAudienceMissBehaviorCancelValue forKey:UAScheduleAudienceMissBehaviorKey];
            break;
        case UAScheduleAudienceMissBehaviorSkip:
            [json setValue:UAScheduleAudienceMissBehaviorSkipValue forKey:UAScheduleAudienceMissBehaviorKey];
            break;
        case UAScheduleAudienceMissBehaviorPenalize:
            [json setValue:UAScheduleAudienceMissBehaviorPenalizeValue forKey:UAScheduleAudienceMissBehaviorKey];
            break;
    }
    
    return [json copy];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (![other isKindOfClass:[self class]]) {
        return NO;
    }

    return [self isEqualToAudience:(UAScheduleAudience *)other];
}

- (BOOL)isEqualToAudience:(nullable UAScheduleAudience *)audience {
    if ((self.notificationsOptIn != audience.notificationsOptIn) && ![self.notificationsOptIn isEqual:audience.notificationsOptIn]) {
        return NO;
    }
    if ((self.locationOptIn != audience.locationOptIn) && ![self.locationOptIn isEqual:audience.locationOptIn]) {
        return NO;
    }
    if ((self.languageIDs != audience.languageIDs) && ![self.languageIDs isEqual:audience.languageIDs]) {
        return NO;
    }
    if ((self.tagSelector != audience.tagSelector) && ![self.tagSelector isEqual:audience.tagSelector]) {
        return NO;
    }
    if ((self.versionPredicate != audience.versionPredicate) && ![self.versionPredicate.payload isEqual:audience.versionPredicate.payload]) {
        return NO;
    }
    if (self.missBehavior != audience.missBehavior) {
        return NO;
    }
    if (self.requiresAnalytics != audience.requiresAnalytics) {
        return NO;
    }
    if ((self.permissionPredicate != audience.permissionPredicate) && ![self.permissionPredicate.payload isEqual:audience.permissionPredicate.payload]) {
        return  NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.notificationsOptIn hash];
    result = 31 * result + [self.locationOptIn hash];
    result = 31 * result + [self.languageIDs hash];
    result = 31 * result + [self.tagSelector hash];
    result = 31 * result + [self.versionPredicate.payload hash];
    result = 31 * result + self.missBehavior;
    result = 31 * result + [self.requiresAnalytics hash];
    result = 31 * result + [self.permissionPredicate.payload hash];
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAScheduleAudience: %@>", [self toJSON]];
}

@end

