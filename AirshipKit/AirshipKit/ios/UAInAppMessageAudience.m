/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageTagSelector.h"
#import "UAJSONPredicate.h"
#import "UAVersionMatcher+Internal.h"
#import "UAGlobal.h"

NSString * const UAInAppMessageAudienceNewUserKey = @"new_user";
NSString * const UAInAppMessageAudienceNotificationOptInKey = @"notifications_opt_in";
NSString * const UAInAppMessageAudienceLocationOptInKey = @"location_opt_in";
NSString * const UAInAppMessageAudienceLanguageTagsKey = @"locale";
NSString * const UAInAppMessageAudienceTagSelectorKey = @"tags";
NSString * const UAInAppMessageAudienceAppVersionKey = @"app_version";

NSString * const UAInAppMessageAudienceErrorDomain = @"com.urbanairship.in_app_message_audience";

@implementation UAInAppMessageAudienceBuilder

@end

@implementation UAInAppMessageAudience

+ (instancetype)audienceWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageAudienceBuilder *builder = [[UAInAppMessageAudienceBuilder alloc] init];
    
    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        return nil;
    }
    
    id onlyNewUser = json[UAInAppMessageAudienceNewUserKey];
    if (onlyNewUser) {
        if (![onlyNewUser isKindOfClass:[NSNumber class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceNewUserKey, onlyNewUser]];
            return nil;
        }
        builder.isNewUser = onlyNewUser;
    }
    
    id notificationsOptIn = json[UAInAppMessageAudienceNotificationOptInKey];
    if (notificationsOptIn) {
        if (![notificationsOptIn isKindOfClass:[NSNumber class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceNotificationOptInKey, notificationsOptIn]];
            return nil;
        }
        builder.notificationsOptIn = notificationsOptIn;
    }
    
    id locationOptIn = json[UAInAppMessageAudienceLocationOptInKey];
    if (locationOptIn) {
        if (![locationOptIn isKindOfClass:[NSNumber class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceLocationOptInKey, locationOptIn]];
            return nil;
        }
        builder.locationOptIn = locationOptIn;
    }

    id languageTags = json[UAInAppMessageAudienceLanguageTagsKey];
    if (languageTags) {
        if (![languageTags isKindOfClass:[NSArray class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be an array. Invalid value: %@", UAInAppMessageAudienceLanguageTagsKey, languageTags]];
            return nil;
        }
        builder.languageTags = languageTags;
    }
    
    id tagSelector = json[UAInAppMessageAudienceTagSelectorKey];
    if (tagSelector) {
        if (![tagSelector isKindOfClass:[NSDictionary class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a dictionary. Invalid value: %@", UAInAppMessageAudienceTagSelectorKey, tagSelector]];
            return nil;
        }
        builder.tagSelector = [UAInAppMessageTagSelector parseJson:tagSelector error:error];
        if (!builder.tagSelector) {
            return nil;
        }
    }
    
    id versionConstraint = json[UAInAppMessageAudienceAppVersionKey];
    if (versionConstraint) {
        if (![versionConstraint isKindOfClass:[NSString class]]) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a string. Invalid value: %@", UAInAppMessageAudienceAppVersionKey, versionConstraint]];
            return nil;
        }
        builder.versionMatcher = [UAVersionMatcher matcherWithVersionConstraint:versionConstraint];
    }
    
    return [[UAInAppMessageAudience alloc] initWithBuilder:builder];
}

+ (NSError *)invalidJSONErrorWithMsg:(NSString *)msg {
    return [NSError errorWithDomain:UAInAppMessageAudienceErrorDomain
                               code:UAInAppMessageAudienceErrorCodeInvalidJSON
                           userInfo:@{NSLocalizedDescriptionKey:msg}];
}

+ (instancetype)audienceWithBuilderBlock:(void(^)(UAInAppMessageAudienceBuilder *builder))builderBlock  {
    UAInAppMessageAudienceBuilder *builder = [[UAInAppMessageAudienceBuilder alloc] init];
    
    if (builderBlock) {
        builderBlock(builder);
    }
    
    return [[UAInAppMessageAudience alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(UAInAppMessageAudienceBuilder *)builder {
    if (self = [super init]) {
        if (![UAInAppMessageAudience validateBuilder:builder]) {
            UA_LDEBUG(@"UAInAppMessageAudience could not be initialized, builder has missing or invalid parameters.");
            return nil;
        }
        
        self.isNewUser = builder.isNewUser;
        self.notificationsOptIn = builder.notificationsOptIn;
        self.locationOptIn = builder.locationOptIn;
        self.languageIDs = builder.languageTags;
        self.tagSelector = builder.tagSelector;
        self.versionMatcher = builder.versionMatcher;
    }
    return self;
}

#pragma mark - Validation

// Validates builder contents
+ (BOOL)validateBuilder:(UAInAppMessageAudienceBuilder *)builder {
    // REVISIT - what do we need to validate this builder?
    return YES;
}

- (NSDictionary *)toJsonValue {
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:1];
    
    if (self.isNewUser) {
        json[UAInAppMessageAudienceNewUserKey] = self.isNewUser;
    }
    if (self.notificationsOptIn) {
        json[UAInAppMessageAudienceNotificationOptInKey] = self.notificationsOptIn;
    }
    if (self.locationOptIn) {
        json[UAInAppMessageAudienceLocationOptInKey] = self.locationOptIn;
    }
    if (self.languageIDs) {
        json[UAInAppMessageAudienceLanguageTagsKey] = self.languageIDs;
    }
    if (self.tagSelector) {
        json[UAInAppMessageAudienceTagSelectorKey] = [self.tagSelector toJsonValue];
    }
    if (self.versionMatcher) {
        json[UAInAppMessageAudienceAppVersionKey] = self.versionMatcher.versionConstraint;
    }
    
    return json;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToAudience:(UAInAppMessageAudience *)other];
}

- (BOOL)isEqualToAudience:(nullable UAInAppMessageAudience *)audience {
    if ((self.isNewUser != audience.isNewUser) && ![self.isNewUser isEqual:audience.isNewUser]) {
        return NO;
    }
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
    if ((self.versionMatcher != audience.versionMatcher) && ![self.versionMatcher isEqual:audience.versionMatcher]) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.isNewUser hash];
    result = 31 * result + [self.notificationsOptIn hash];
    result = 31 * result + [self.locationOptIn hash];
    result = 31 * result + [self.languageIDs hash];
    result = 31 * result + [self.tagSelector hash];
    result = 31 * result + [self.versionMatcher hash];
    return result;
}

@end
