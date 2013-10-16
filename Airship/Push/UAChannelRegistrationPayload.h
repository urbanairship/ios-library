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


#import <Foundation/Foundation.h>

typedef NSString *const UAChannelJSONKey;

extern UAChannelJSONKey UAChannelDeviceTypeKey;
extern UAChannelJSONKey UAChannelTransportKey;
extern UAChannelJSONKey UAChannelOptInKey;
extern UAChannelJSONKey UAChannelPushAddressKey;
extern UAChannelJSONKey UAChannelIdentityHintsKey;
extern UAChannelJSONKey UAChannelUserIDKey;
extern UAChannelJSONKey UAChannelDeviceIDKey;
extern UAChannelJSONKey UAChanneliOSKey;
extern UAChannelJSONKey UAChannelBadgeJSONKey;
extern UAChannelJSONKey UAChannelQuietTimeJSONKey;
extern UAChannelJSONKey UAChannelTimeZoneJSONKey;
extern UAChannelJSONKey UAChannelAliasJSONKey;
extern UAChannelJSONKey UAChannelSetTagsKey;
extern UAChannelJSONKey UAChannelTagsJSONKey;


@interface UAChannelRegistrationPayload : NSObject<NSCopying>


@property(nonatomic, copy)NSString *userID;
@property(nonatomic, copy)NSString *deviceID;

@property(nonatomic, assign)BOOL optedIn;
@property(nonatomic, copy)NSString *pushAddress;

@property(nonatomic, assign)BOOL setTags;
@property(nonatomic, strong)NSArray *tags;

@property(nonatomic, copy)NSString *alias;

@property(nonatomic, strong)NSDictionary *quietTime;
@property(nonatomic, copy)NSString *timeZone;

@property(nonatomic, strong)NSNumber *badge;


- (NSData *)asJSONData;

- (BOOL)isEqualToPayload:(UAChannelRegistrationPayload *)payload;
@end
