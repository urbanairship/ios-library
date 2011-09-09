/*
Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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

#import "UAGlobal.h"
#import "UAObservable.h"
#import "UAAnalytics.h"

UA_VERSION_INTERFACE(AirshipVersion)

extern NSString * const UAirshipTakeOffOptionsAirshipConfigKey;
extern NSString * const UAirshipTakeOffOptionsLaunchOptionsKey;
extern NSString * const UAirshipTakeOffOptionsAnalyticsKey;
extern NSString * const UAirshipTakeOffOptionsDefaultUsernameKey;
extern NSString * const UAirshipTakeOffOptionsDefaultPasswordKey;

@class UA_ASIHTTPRequest;

@protocol UARegistrationObserver
@optional
- (void)registerDeviceTokenSucceeded;
- (void)registerDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)unRegisterDeviceTokenSucceeded;
- (void)unRegisterDeviceTokenFailed:(UA_ASIHTTPRequest *)request;
- (void)addTagToDeviceSucceeded;
- (void)addTagToDeviceFailed:(UA_ASIHTTPRequest *)request;
- (void)removeTagFromDeviceSucceeded;
- (void)removeTagFromDeviceFailed:(UA_ASIHTTPRequest *)request;
@end


@interface UAirship : UAObservable {
    NSString *server;
    NSString *appId;
    NSString *appSecret;

    NSString *deviceToken;
    NSString *deviceAlias;
    BOOL deviceTokenHasChanged;
    BOOL ready;

    UA_ASIHTTPRequest *registerRequest;
}

@property (nonatomic, retain) NSString *deviceToken;
@property (nonatomic, retain) UAAnalytics *analytics;

@property (retain) NSString *server;
@property (retain) NSString *appId;
@property (retain) NSString *appSecret;
@property (assign) BOOL deviceTokenHasChanged;
@property (assign) BOOL ready;

// Lifecycle
+ (UAirship *)shared;
+ (void)setLogging:(BOOL)value;
+ (void)takeOff:(NSDictionary *)options;
+ (void)land;

// callback for succeed register APN device token
- (void)registerDeviceToken:(NSData *)token;

// Register DeviceToken to UA
- (void)registerDeviceTokenWithExtraInfo:(NSDictionary *)info;
- (void)registerDeviceToken:(NSData *)token withAlias:(NSString *)alias;
- (void)registerDeviceToken:(NSData *)token withExtraInfo:(NSDictionary *)info;
- (void)unRegisterDeviceToken;

// Update device token without remote registration
- (void)updateDeviceToken:(NSData *)token;

@end
