/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageAudience+Internal.h"
#import "UAInAppMessageTagSelector+Internal.h"
#import "UAJSONPredicate.h"
#import "UAVersionMatcher+Internal.h"
#import "UAGlobal.h"

NSString * const UAInAppMessageAudienceNewUserKey = @"new_user";
NSString * const UAInAppMessageAudienceNotificationOptInKey = @"notifications_opt_in";
NSString * const UAInAppMessageAudienceLocationOptInKey = @"location_opt_in";
NSString * const UAInAppMessageAudienceLanguageTagsKey = @"locale";
NSString * const UAInAppMessageAudienceTagSelectorKey = @"tags";
NSString * const UAInAppMessageAudienceAppVersionKey = @"app_version";
NSString * const UAInAppMessageAudienceTestDevicesKey = @"test_devices";

NSString * const UAInAppMessageAudienceErrorDomain = @"com.urbanairship.in_app_message_audience";

@interface UAInAppMessageAudience()
@property(nonatomic, strong, nullable) NSNumber *notificationsOptIn;
@property(nonatomic, strong, nullable) NSNumber *locationOptIn;
@property(nonatomic, strong, nullable) NSArray<NSString *> *languageIDs;
@property(nonatomic, strong, nullable) UAInAppMessageTagSelector *tagSelector;
@property(nonatomic, strong, nullable) UAJSONPredicate *versionPredicate;
@end

@implementation UAInAppMessageAudienceBuilder

- (BOOL)isValid {
    return YES;
}

@end

@implementation UAInAppMessageAudience

@synthesize isNewUser = _isNewUser;
@synthesize testDevices = _testDevices;

+ (instancetype)audienceWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageAudienceBuilder *builder = [[UAInAppMessageAudienceBuilder alloc] init];

    if (!json || ![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Json must be a dictionary. Invalid value: %@", json]];
        }
        return nil;
    }

    id onlyNewUser = json[UAInAppMessageAudienceNewUserKey];
    if (onlyNewUser) {
        if (![onlyNewUser isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceNewUserKey, onlyNewUser]];
            }
            return nil;
        }
        builder.isNewUser = onlyNewUser;
    }

    id notificationsOptIn = json[UAInAppMessageAudienceNotificationOptInKey];
    if (notificationsOptIn) {
        if (![notificationsOptIn isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceNotificationOptInKey, notificationsOptIn]];
            }
            return nil;
        }
        builder.notificationsOptIn = notificationsOptIn;
    }

    id locationOptIn = json[UAInAppMessageAudienceLocationOptInKey];
    if (locationOptIn) {
        if (![locationOptIn isKindOfClass:[NSNumber class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be a boolean. Invalid value: %@", UAInAppMessageAudienceLocationOptInKey, locationOptIn]];
            }
            return nil;
        }
        builder.locationOptIn = locationOptIn;
    }

    id languageTags = json[UAInAppMessageAudienceLanguageTagsKey];
    if (languageTags) {
        if (![languageTags isKindOfClass:[NSArray class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be an array. Invalid value: %@", UAInAppMessageAudienceLanguageTagsKey, languageTags]];
            }
            return nil;
        }
        builder.languageTags = languageTags;
    }

    id tagSelector = json[UAInAppMessageAudienceTagSelectorKey];
    if (tagSelector) {
        builder.tagSelector = [UAInAppMessageTagSelector selectorWithJSON:tagSelector error:error];
        if (!builder.tagSelector) {
            return nil;
        }
    }

    id versionPredicate = json[UAInAppMessageAudienceAppVersionKey];
    if (versionPredicate) {
        builder.versionPredicate = [UAJSONPredicate predicateWithJSON:versionPredicate error:error];
        if (!builder.versionPredicate) {
            return nil;
        }
    }

    id testDevices = json[UAInAppMessageAudienceTestDevicesKey];
    if (testDevices) {
        if (![testDevices isKindOfClass:[NSArray class]]) {
            if (error) {
                *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Value for the \"%@\" key must be an array. Invalid value: %@", UAInAppMessageAudienceTestDevicesKey, testDevices]];
            }
            return nil;
        }

        for (id value in testDevices) {
            if (![value isKindOfClass:[NSString class]]) {
                if (error) {
                    *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Invalid test device value: %@", value]];
                }
                return nil;
            }
        }

        builder.testDevices = testDevices;
    }

    if (![builder isValid]) {
        if (error) {
            *error = [self invalidJSONErrorWithMsg:[NSString stringWithFormat:@"Invalid audience %@", json]];
        }

        return nil;
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
        if (![builder isValid]) {
            UA_LDEBUG(@"UAInAppMessageAudience could not be initialized, builder has missing or invalid parameters.");
            return nil;
        }

        _isNewUser = builder.isNewUser;
        _testDevices = builder.testDevices;
        self.notificationsOptIn = builder.notificationsOptIn;
        self.locationOptIn = builder.locationOptIn;
        self.languageIDs = builder.languageTags;
        self.tagSelector = builder.tagSelector;
        self.versionPredicate = builder.versionPredicate;

    }
    return self;
}

- (NSArray *)testDevices {
    return _testDevices;
}

- (NSNumber *)isNewUser {
    return _isNewUser;
}

#pragma mark - Validation


- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setValue:self.isNewUser forKey:UAInAppMessageAudienceNewUserKey];
    [json setValue:self.notificationsOptIn forKey:UAInAppMessageAudienceNotificationOptInKey];
    [json setValue:self.locationOptIn forKey:UAInAppMessageAudienceLocationOptInKey];
    [json setValue:self.languageIDs forKey:UAInAppMessageAudienceLanguageTagsKey];
    [json setValue:[self.tagSelector toJSON] forKey:UAInAppMessageAudienceTagSelectorKey];
    [json setValue:self.versionPredicate.payload forKey:UAInAppMessageAudienceAppVersionKey];
    [json setValue:self.testDevices forKey:UAInAppMessageAudienceTestDevicesKey];
    return [json copy];
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
    if ((self.versionPredicate != audience.versionPredicate) && ![self.versionPredicate.payload isEqual:audience.versionPredicate.payload]) {
        return NO;
    }
    if ((self.testDevices != audience.testDevices) && ![self.testDevices isEqual:audience.testDevices]) {
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
    result = 31 * result + [self.versionPredicate.payload hash];
    result = 31 * result + [self.testDevices hash];
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageAudience: %@>", [self toJSON]];
}

@end

