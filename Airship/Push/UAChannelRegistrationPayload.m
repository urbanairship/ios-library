/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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



@implementation UAChannelRegistrationPayload

- (NSData *)asJSONData {
    return [NSJSONSerialization dataWithJSONObject:[self payloadDictionary]
                                           options:0
                                             error:nil];
}

- (NSDictionary *)payloadDictionary {
    NSMutableDictionary *payloadDictionary = [NSMutableDictionary dictionary];

    if (self.deviceID || self.userID) {
        NSMutableDictionary *identityHints = [NSMutableDictionary dictionary];
        [identityHints setValue:self.userID forKey:kUAChannelUserIDKey];
        [identityHints setValue:self.deviceID forKey:kUAChannelDeviceIDKey];
        [payloadDictionary setValue:identityHints forKey:kUAChannelIdentityHintsKey];
    }

    // Channel is a top level object containing channel related fields.
    NSMutableDictionary *channel = [NSMutableDictionary dictionary];
    [channel setValue:@"ios" forKey:kUAChannelDeviceTypeKey];
    [channel setValue:[NSNumber numberWithBool:self.optedIn] forKey:kUAChannelOptInKey];
    [channel setValue:[NSNumber numberWithBool:self.backgroundEnabled] forKey:kUABackgroundEnabledJSONKey];
    [channel setValue:self.pushAddress forKey:kUAChannelPushAddressKey];

    self.alias = [self.alias stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([self.alias length] > 0) {
        [channel setValue:self.alias forKey:kUAChannelAliasJSONKey];
    }

    [channel setValue:[NSNumber numberWithBool:self.setTags] forKey:kUAChannelSetTagsKey];
    if (self.setTags) {
        [channel setValue:self.tags forKey:kUAChannelTagsJSONKey];
    }

    if (self.badge || self.quietTime || self.timeZone) {
        NSMutableDictionary *ios = [NSMutableDictionary dictionary];
        [ios setValue:self.badge forKey:kUAChannelBadgeJSONKey];
        [ios setValue:self.quietTime forKey:kUAChannelQuietTimeJSONKey];
        [ios setValue:self.timeZone forKey:kUAChannelTimeZoneJSONKey];
        [channel setValue:ios forKey:kUAChanneliOSKey];
    }

    [payloadDictionary setValue:channel forKey:kUAChannelKey];

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
        copy.alias = self.alias;
        copy.quietTime = [self.quietTime copyWithZone:zone];
        copy.timeZone = self.timeZone;
        copy.badge = [self.badge copyWithZone:zone];
    }

    return copy;
}

- (BOOL)isEqualToPayload:(UAChannelRegistrationPayload *)payload {
    return [[self payloadDictionary] isEqualToDictionary:[payload payloadDictionary]];
}

- (NSString *)description {
    return [[self payloadDictionary] description];
}

@end
