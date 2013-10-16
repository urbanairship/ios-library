/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAChannelRegistrationPayload.h"

UAChannelJSONKey UAChannelDeviceTypeKey = @"device_type";
UAChannelJSONKey UAChannelTransportKey = @"transport";
UAChannelJSONKey UAChannelOptInKey = @"opt-in";
UAChannelJSONKey UAChannelPushAddressKey = @"push-address";

UAChannelJSONKey UAChannelIdentityHintsKey = @"identity_hints";
UAChannelJSONKey UAChannelUserIDKey = @"user_id";
UAChannelJSONKey UAChannelDeviceIDKey = @"device_id";

UAChannelJSONKey UAChanneliOSKey = @"ios";
UAChannelJSONKey UAChannelBadgeJSONKey = @"badge";
UAChannelJSONKey UAChannelQuietTimeJSONKey = @"quiettime";
UAChannelJSONKey UAChannelTimeZoneJSONKey = @"tz";

UAChannelJSONKey UAChannelAliasJSONKey = @"alias";
UAChannelJSONKey UAChannelSetTagsKey = @"set_tags";
UAChannelJSONKey UAChannelTagsJSONKey = @"tags";

@implementation UAChannelRegistrationPayload

- (NSData *)asJSONData {
    return [NSJSONSerialization dataWithJSONObject:[self payloadDictionary]
                                           options:0
                                             error:nil];
}

- (NSDictionary *)payloadDictionary {
    NSMutableDictionary *payloadDictionary = [NSMutableDictionary dictionary];

    [payloadDictionary setValue:@"ios" forKey:UAChannelDeviceTypeKey];
    [payloadDictionary setValue:@"apns" forKey:UAChannelTransportKey];
    [payloadDictionary setValue:[NSNumber numberWithBool:self.optedIn] forKey:UAChannelOptInKey];
    [payloadDictionary setValue:self.pushAddress forKey:UAChannelPushAddressKey];

    if (self.deviceID || self.userID) {
        NSMutableDictionary *identityHints = [NSMutableDictionary dictionary];
        [identityHints setValue:self.userID forKey:UAChannelUserIDKey];
        [identityHints setValue:self.deviceID forKey:UAChannelDeviceIDKey];
        [payloadDictionary setValue:identityHints forKey:UAChannelIdentityHintsKey];
    }

    if (self.badge || self.quietTime || self.timeZone) {
        NSMutableDictionary *ios = [NSMutableDictionary dictionary];
        [ios setValue:self.badge forKey:UAChannelBadgeJSONKey];
        [ios setValue:self.quietTime forKey:UAChannelQuietTimeJSONKey];
        [ios setValue:self.timeZone forKey:UAChannelTimeZoneJSONKey];
        [payloadDictionary setValue:ios forKey:UAChanneliOSKey];
    }

    [payloadDictionary setValue:self.alias forKey:UAChannelAliasJSONKey];

    [payloadDictionary setValue:[NSNumber numberWithBool:self.setTags] forKey:UAChannelSetTagsKey];
    [payloadDictionary setValue:self.tags forKey:UAChannelTagsJSONKey];

    return payloadDictionary;
}

- (id)copyWithZone:(NSZone *)zone {
    UAChannelRegistrationPayload *copy = [[[self class] alloc] init];

    if (copy) {
        copy.userID = self.userID;
        copy.deviceID = self.deviceID;
        copy.optedIn = self.optedIn;
        copy.pushAddress = self.pushAddress;
        copy.setTags = self.setTags;
        copy.tags = [self.tags copyWithZone:zone];
        copy.alias = self.alias;
        copy.quietTime = [self.quietTime copyWithZone:zone];
        copy.timeZone = self.timeZone;
        copy.badge = [self.badge copyWithZone:zone];
    }

    return copy;
}

- (BOOL)isEqualToPayload:(UAChannelRegistrationPayload *)payload {
    return (self.optedIn == payload.optedIn &&
            self.setTags == payload.setTags &&
            [self.userID isEqualToString:payload.userID] &&
            [self.deviceID isEqualToString:payload.deviceID] &&
            [self.pushAddress isEqualToString:payload.pushAddress] &&
            [self.tags isEqualToArray:payload.tags] &&
            [self.alias isEqualToString:payload.alias] &&
            [self.quietTime isEqualToDictionary:payload.quietTime] &&
            [self.timeZone isEqualToString:payload.timeZone] &&
            [self.badge isEqualToNumber:payload.badge]);
}


@end
