/* Copyright Urban Airship and Contributors */

#import "UAChannelRegistrationPayload+Internal.h"
#import "UAirship.h"
#import "UAAnalytics.h"
#import "UAJSONSerialization+Internal.h"

NSString *const UAChannelIdentityHintsKey = @"identity_hints";
NSString *const UAChannelUserIDKey = @"user_id";
NSString *const UAChannelDeviceIDKey = @"device_id";

NSString *const UAChannelKey = @"channel";
NSString *const UAPlatformKey= @"ios";
NSString *const UAChannelDeviceTypeKey = @"device_type";
NSString *const UAChannelOptInKey = @"opt_in";
NSString *const UAChannelPushAddressKey = @"push_address";

NSString *const UAChannelTopLevelTimeZoneJSONKey = @"timezone";
NSString *const UAChannelTopLevelLanguageJSONKey = @"locale_language";
NSString *const UAChannelTopLevelCountryJSONKey = @"locale_country";

NSString *const UAChanneliOSKey = @"ios";
NSString *const UAChannelBadgeJSONKey = @"badge";
NSString *const UAChannelQuietTimeJSONKey = @"quiettime";
NSString *const UAChannelTimeZoneJSONKey = @"tz";

NSString *const UAChannelAliasJSONKey = @"alias";
NSString *const UAChannelSetTagsKey = @"set_tags";
NSString *const UAChannelTagsJSONKey = @"tags";

NSString *const UABackgroundEnabledJSONKey = @"background";

@implementation UAChannelRegistrationPayload

+ (UAChannelRegistrationPayload *)channelRegistrationPayloadWithData:(NSData *)data {
    return [[UAChannelRegistrationPayload alloc] initWithData:data];
}

- (UAChannelRegistrationPayload *)initWithData:(NSData *)data {
    self = [super init];

    if (self) {
        if (!data) {
            UA_LERR(@"Failed to create channel registraion payload from data, data is nil");
            return nil;
        }

        NSDictionary *dataDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

        NSDictionary *topLevel = dataDictionary[UAChannelKey];
        NSDictionary *identityHints = dataDictionary[UAChannelIdentityHintsKey];

        if (topLevel != nil) {
            NSDictionary *platform = topLevel[UAPlatformKey];

            if (platform != nil) {
                self.badge = platform[UAChannelBadgeJSONKey];
                self.quietTime = platform[UAChannelQuietTimeJSONKey];
            }

            self.deviceID = topLevel[UAChannelDeviceIDKey];
            self.pushAddress = topLevel[UAChannelPushAddressKey];
            self.userID = topLevel[UAChannelUserIDKey];
            self.optedIn = [topLevel[UAChannelOptInKey] boolValue];
            self.backgroundEnabled = [topLevel[UABackgroundEnabledJSONKey] boolValue];
            self.setTags = [topLevel[UAChannelSetTagsKey] boolValue];
            self.tags = topLevel[UAChannelTagsJSONKey];
            self.language = topLevel[UAChannelTopLevelLanguageJSONKey];
            self.country = topLevel[UAChannelTopLevelCountryJSONKey];
            self.timeZone = topLevel[UAChannelTopLevelTimeZoneJSONKey];
        }

        if (identityHints != nil) {
            self.userID = self.userID ?: identityHints[UAChannelUserIDKey];
            self.deviceID = self.deviceID ?: identityHints[UAChannelDeviceIDKey];
        }
    }

    return self;
}

- (NSData *)asJSONData {
    return [UAJSONSerialization dataWithJSONObject:[self payloadDictionary]
                                           options:0
                                             error:nil];
}

- (NSDictionary *)payloadDictionary {
    NSMutableDictionary *payloadDictionary = [NSMutableDictionary dictionary];

    if (self.deviceID || self.userID) {
        NSMutableDictionary *identityHints = [NSMutableDictionary dictionary];
        [identityHints setValue:self.userID forKey:UAChannelUserIDKey];
        [identityHints setValue:self.deviceID forKey:UAChannelDeviceIDKey];
        [payloadDictionary setValue:identityHints forKey:UAChannelIdentityHintsKey];
    }

    // Channel is a top level object containing channel related fields.
    NSMutableDictionary *channel = [NSMutableDictionary dictionary];
    [channel setValue:@"ios" forKey:UAChannelDeviceTypeKey];
    [channel setValue:[NSNumber numberWithBool:self.optedIn] forKey:UAChannelOptInKey];
#if TARGET_OS_TV    // REVISIT - do we need to force self.backgroundEnabled to YES?? - may be a hacking artifact
    [channel setValue:[NSNumber numberWithBool:YES] forKey:UABackgroundEnabledJSONKey];
#else
    [channel setValue:[NSNumber numberWithBool:self.backgroundEnabled] forKey:UABackgroundEnabledJSONKey];
#endif
    [channel setValue:self.pushAddress forKey:UAChannelPushAddressKey];

    [channel setValue:[NSNumber numberWithBool:self.setTags] forKey:UAChannelSetTagsKey];
    if (self.setTags) {
        [channel setValue:self.tags forKey:UAChannelTagsJSONKey];
    }

    if (self.badge || self.quietTime) {
        NSMutableDictionary *ios = [NSMutableDictionary dictionary];
        [ios setValue:self.badge forKey:UAChannelBadgeJSONKey];
        [ios setValue:self.quietTime forKey:UAChannelQuietTimeJSONKey];
        [ios setValue:self.timeZone forKey:UAChannelTimeZoneJSONKey];
        [channel setValue:ios forKey:UAChanneliOSKey];
    }

    // Set top level timezone and language keys
    [channel setValue:self.timeZone forKey:UAChannelTopLevelTimeZoneJSONKey];
    [channel setValue:self.language forKey:UAChannelTopLevelLanguageJSONKey];
    [channel setValue:self.country forKey:UAChannelTopLevelCountryJSONKey];

    [payloadDictionary setValue:channel forKey:UAChannelKey];

    return payloadDictionary;
}

- (id)copyWithZone:(NSZone *)zone {
    UAChannelRegistrationPayload *copy = [[[self class] alloc] init];

    if (copy) {
        copy.userID = self.userID;
        copy.deviceID = self.deviceID;
        copy.optedIn = self.optedIn;
        copy.backgroundEnabled = self.backgroundEnabled;
        copy.pushAddress = self.pushAddress;
        copy.setTags = self.setTags;
        copy.tags = [self.tags copyWithZone:zone];
        copy.quietTime = [self.quietTime copyWithZone:zone];
        copy.timeZone = self.timeZone;
        copy.language = self.language;
        copy.country = self.country;
        copy.badge = [self.badge copyWithZone:zone];
    }

    return copy;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToPayload:(UAChannelRegistrationPayload *)other];
}

- (BOOL)isEqualToPayload:(UAChannelRegistrationPayload *)payload {
    return [[self payloadDictionary] isEqualToDictionary:[payload payloadDictionary]];
}

- (NSUInteger)hash {
    NSUInteger result = [self.payloadDictionary hash];
    return result;
}
- (NSString *)description {
    return [[self payloadDictionary] description];
}

@end
