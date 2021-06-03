/* Copyright Airship and Contributors */

#import "UAChannelRegistrationPayload+Internal.h"
#import "UAJSONSerialization.h"
#import "UAGlobal.h"

NSString *const UAChannelIOSPlatform= @"ios";

NSString *const UAChannelIdentityHintsKey = @"identity_hints";
NSString *const UAChannelUserIDKey = @"user_id";
NSString *const UAChannelDeviceIDKey = @"device_id";
NSString *const UAChannelAccengageDeviceIDKey = @"accengage_device_id";

NSString *const UAChannelKey = @"channel";
NSString *const UAChannelDeviceTypeKey = @"device_type";
NSString *const UAChannelOptInKey = @"opt_in";
NSString *const UAChannelPushAddressKey = @"push_address";
NSString *const UAChannelNamedUserIdKey = @"named_user_id";

NSString *const UAChannelTopLevelTimeZoneJSONKey = @"timezone";
NSString *const UAChannelTopLevelLanguageJSONKey = @"locale_language";
NSString *const UAChannelTopLevelCountryJSONKey = @"locale_country";
NSString *const UAChannelTopLevelLocationSettingsJSONKey = @"location_settings";
NSString *const UAChannelTopLevelAppVersionJSONKey = @"app_version";
NSString *const UAChannelTopLevelSDKVersionJSONKey = @"sdk_version";
NSString *const UAChannelTopLevelDeviceModelJSONKey = @"device_model";
NSString *const UAChannelTopLevelDeviceOSJSONKey = @"device_os";
NSString *const UAChannelTopLevelCarrierJSONKey = @"carrier";

NSString *const UAChannelIOSKey = @"ios";
NSString *const UAChannelBadgeJSONKey = @"badge";
NSString *const UAChannelQuietTimeJSONKey = @"quiettime";
NSString *const UAChannelTimeZoneJSONKey = @"tz";

NSString *const UAChannelAliasJSONKey = @"alias";
NSString *const UAChannelSetTagsKey = @"set_tags";
NSString *const UAChannelTagsJSONKey = @"tags";
NSString *const UAChannelTagChangesJSONKey = @"tag_changes";
NSString *const UAChannelTagChangesAddJSONKey = @"add";
NSString *const UAChannelTagChangesRemoveJSONKey = @"remove";

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
            NSDictionary *platform = topLevel[UAChannelIOSKey];

            if (platform != nil) {
                self.badge = platform[UAChannelBadgeJSONKey];
                self.quietTime = platform[UAChannelQuietTimeJSONKey];
                self.quietTimeTimeZone = platform[UAChannelTimeZoneJSONKey];
            }

            self.deviceID = topLevel[UAChannelDeviceIDKey];
            self.pushAddress = topLevel[UAChannelPushAddressKey];
            self.namedUserId = topLevel[UAChannelNamedUserIdKey];
            self.userID = topLevel[UAChannelUserIDKey];
            self.accengageDeviceID = topLevel[UAChannelAccengageDeviceIDKey];
            self.optedIn = [topLevel[UAChannelOptInKey] boolValue];
            self.backgroundEnabled = [topLevel[UABackgroundEnabledJSONKey] boolValue];
            self.setTags = [topLevel[UAChannelSetTagsKey] boolValue];
            self.tags = topLevel[UAChannelTagsJSONKey];
            self.tagChanges = topLevel[UAChannelTagChangesJSONKey];
            self.language = topLevel[UAChannelTopLevelLanguageJSONKey];
            self.country = topLevel[UAChannelTopLevelCountryJSONKey];
            self.timeZone = topLevel[UAChannelTopLevelTimeZoneJSONKey];
            self.locationSettings = topLevel[UAChannelTopLevelLocationSettingsJSONKey];
            self.appVersion = topLevel[UAChannelTopLevelAppVersionJSONKey];
            self.SDKVersion = topLevel[UAChannelTopLevelSDKVersionJSONKey];
            self.deviceModel = topLevel[UAChannelTopLevelDeviceModelJSONKey];
            self.deviceOS = topLevel[UAChannelTopLevelDeviceOSJSONKey];
            self.carrier = topLevel[UAChannelTopLevelCarrierJSONKey];
        }

        if (identityHints != nil) {
            self.userID = self.userID ?: identityHints[UAChannelUserIDKey];
            self.deviceID = self.deviceID ?: identityHints[UAChannelDeviceIDKey];
            self.accengageDeviceID = self.accengageDeviceID ?: identityHints[UAChannelAccengageDeviceIDKey];
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

    if (self.deviceID || self.userID || self.accengageDeviceID) {
        NSMutableDictionary *identityHints = [NSMutableDictionary dictionary];
        [identityHints setValue:self.userID forKey:UAChannelUserIDKey];
        [identityHints setValue:self.deviceID forKey:UAChannelDeviceIDKey];
        [identityHints setValue:self.accengageDeviceID forKey:UAChannelAccengageDeviceIDKey];
        [payloadDictionary setValue:identityHints forKey:UAChannelIdentityHintsKey];
    }

    // Channel is a top level object containing channel related fields.
    NSMutableDictionary *channel = [NSMutableDictionary dictionary];
    [channel setValue:UAChannelIOSPlatform forKey:UAChannelDeviceTypeKey];
    [channel setValue:[NSNumber numberWithBool:self.optedIn] forKey:UAChannelOptInKey];
    [channel setValue:[NSNumber numberWithBool:self.backgroundEnabled] forKey:UABackgroundEnabledJSONKey];
    [channel setValue:self.pushAddress forKey:UAChannelPushAddressKey];

    [channel setValue:self.namedUserId forKey:UAChannelNamedUserIdKey];

    [channel setValue:[NSNumber numberWithBool:self.setTags] forKey:UAChannelSetTagsKey];
    if (self.setTags) {
        [channel setValue:self.tags forKey:UAChannelTagsJSONKey];
        [channel setValue:self.tagChanges forKey:UAChannelTagChangesJSONKey];
    }

    NSMutableDictionary *ios = [NSMutableDictionary dictionary];
    [ios setValue:self.badge forKey:UAChannelBadgeJSONKey];

    if (self.quietTime) {
        [ios setValue:self.quietTime forKey:UAChannelQuietTimeJSONKey];
        [ios setValue:(self.quietTimeTimeZone ?: self.timeZone) forKey:UAChannelTimeZoneJSONKey];
    }

    if (ios.count) {
        [channel setValue:ios forKey:UAChannelIOSKey];
    }

    [channel setValue:self.timeZone forKey:UAChannelTopLevelTimeZoneJSONKey];
    [channel setValue:self.language forKey:UAChannelTopLevelLanguageJSONKey];
    [channel setValue:self.country forKey:UAChannelTopLevelCountryJSONKey];
    [channel setValue:self.locationSettings forKey:UAChannelTopLevelLocationSettingsJSONKey];
    [channel setValue:self.appVersion forKey:UAChannelTopLevelAppVersionJSONKey];
    [channel setValue:self.SDKVersion forKey:UAChannelTopLevelSDKVersionJSONKey];
    [channel setValue:self.deviceModel forKey:UAChannelTopLevelDeviceModelJSONKey];
    [channel setValue:self.deviceOS forKey:UAChannelTopLevelDeviceOSJSONKey];
    [channel setValue:self.carrier forKey:UAChannelTopLevelCarrierJSONKey];

    [payloadDictionary setValue:channel forKey:UAChannelKey];

    return payloadDictionary;
}

- (id)copyWithZone:(NSZone *)zone {
    UAChannelRegistrationPayload *copy = [[[self class] alloc] init];

    if (copy) {
        copy.userID = self.userID;
        copy.deviceID = self.deviceID;
        copy.accengageDeviceID = self.accengageDeviceID;
        copy.optedIn = self.optedIn;
        copy.backgroundEnabled = self.backgroundEnabled;
        copy.pushAddress = self.pushAddress;
        copy.namedUserId = self.namedUserId;
        copy.setTags = self.setTags;
        copy.tags = [self.tags copyWithZone:zone];
        copy.tagChanges = [self.tagChanges copyWithZone:zone];
        copy.quietTime = [self.quietTime copyWithZone:zone];
        copy.quietTimeTimeZone = self.quietTimeTimeZone;
        copy.timeZone = self.timeZone;
        copy.language = self.language;
        copy.country = self.country;
        copy.badge = [self.badge copyWithZone:zone];
        copy.locationSettings = [self.locationSettings copyWithZone:zone];
        copy.appVersion = self.appVersion;
        copy.SDKVersion = self.SDKVersion;
        copy.deviceModel = self.deviceModel;
        copy.deviceOS = self.deviceOS;
        copy.carrier = self.carrier;
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

- (UAChannelRegistrationPayload *)minimalUpdatePayloadWithLastPayload:(UAChannelRegistrationPayload *)lastPayload {
    UAChannelRegistrationPayload *minPayload = [self copy];

    if (!lastPayload) {
        return minPayload;
    }

    // Strip out tags if they have not changed
    if (lastPayload.setTags && self.setTags) {
        if ([lastPayload.tags isEqualToArray:self.tags]) {
            minPayload.setTags = NO;
            minPayload.tags = nil;
        } else {
            minPayload.tagChanges = [self getTagChanges:lastPayload.tags];
        }
    }

    // Strip identity hints
    minPayload.userID = nil;
    minPayload.deviceID = nil;
    minPayload.accengageDeviceID = nil;

    // Only remove attributes if named user Id is null or is the same as the last payload
    if (!self.namedUserId || ([lastPayload.namedUserId isEqual:self.namedUserId])) {
        // Optional attributes
        if ([self.country isEqual:lastPayload.country]) {
            minPayload.country = nil;
        }
        
        if ([self.language isEqual:lastPayload.language]) {
            minPayload.language = nil;
        }
        
        if ([self.timeZone isEqual:lastPayload.timeZone]) {
            minPayload.timeZone = nil;
        }

        if ([self.locationSettings isEqual:lastPayload.locationSettings]) {
            minPayload.locationSettings = nil;
        }
        
        if ([self.appVersion isEqual:lastPayload.appVersion]) {
            minPayload.appVersion = nil;
        }
        
        if ([self.SDKVersion isEqual:lastPayload.SDKVersion]) {
            minPayload.SDKVersion = nil;
        }
        
        if ([self.deviceModel isEqual:lastPayload.deviceModel]) {
            minPayload.deviceModel = nil;
        }

        if ([self.deviceOS isEqual:lastPayload.deviceOS]) {
            minPayload.deviceOS = nil;
        }
        
        if ([self.carrier isEqual:lastPayload.carrier]) {
            minPayload.carrier = nil;
        }
    }

    return minPayload;
}

- (NSDictionary *)getTagChanges:(NSArray<NSString *> *)lastTags {
    NSMutableArray *add = [@[] mutableCopy];
    for (NSString* tag in self.tags)
    {
        if (![lastTags containsObject:tag])
        {
            [add addObject:tag];
        }
    }
    
    NSMutableArray *remove = [@[] mutableCopy];
    for (NSString* tag in lastTags)
    {
        if (![self.tags containsObject:tag])
        {
            [remove addObject:tag];
        }
    }
    
    NSMutableDictionary *tagChanges = [[NSMutableDictionary alloc] initWithCapacity:2];
    if ([add count] > 0)
    {
        [tagChanges setValue:add forKey:UAChannelTagChangesAddJSONKey];
    }
    if ([remove count] > 0)
    {
        [tagChanges setValue:remove forKey:UAChannelTagChangesRemoveJSONKey];
    }
    
    return tagChanges;
}

@end
