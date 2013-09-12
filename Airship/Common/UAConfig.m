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
#import <objc/runtime.h>

#import "UAConfig+Internal.h"
#import "UAGlobal.h"

@implementation UAConfig

#pragma mark -
#pragma mark Object Lifecycle
- (void)dealloc {
    self.developmentAppKey = nil;
    self.developmentAppSecret = nil;
    
    self.productionAppKey = nil;
    self.productionAppSecret = nil;
    
    self.deviceAPIURL = nil;
    self.analyticsURL = nil;

    self.profilePath = nil;

    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        self.deviceAPIURL = kAirshipProductionServer;
        self.analyticsURL = kAnalyticsProductionServer;
        self.developmentLogLevel = UALogLevelDebug;
        self.productionLogLevel = UALogLevelError;
        self.inProduction = NO;
        self.detectProvisioningMode = NO;
        self.automaticSetupEnabled = YES;
        self.analyticsEnabled = YES;
        self.profilePath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
        usesProductionPushServer_ = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Resolved App Key: %@\n"
            "Resolved App Secret: %@\n"
            "In Production (resolved): %d\n"
            "In Production (as set): %d\n"
            "Development App Key: %@\n"
            "Development App Secret: %@\n"
            "Production App Key: %@\n"
            "Production App Secret: %@\n"
            "Development Log Level: %d\n"
            "Production Log Level: %d\n"
            "Resolved Log Level: %d\n"
            "Detect Provisioning Mode: %d\n"
            "Clear Keychain: %d\n"
            "Analytics Enabled: %d\n"
            "Analytics URL: %@\n"
            "Device API URL: %@\n",
            self.appKey,
            self.appSecret,
            self.inProduction,
            _inProduction,
            self.developmentAppKey,
            self.developmentAppSecret,
            self.productionAppKey,
            self.productionAppSecret,
            self.developmentLogLevel,
            self.productionLogLevel,
            self.logLevel,
            self.detectProvisioningMode,
            self.clearKeychain,
            self.analyticsEnabled,
            self.analyticsURL,
            self.deviceAPIURL];
}

#pragma mark -
#pragma Factory Methods

+ (UAConfig *)defaultConfig {
    return [UAConfig configWithContentsOfFile:
            [[NSBundle mainBundle] pathForResource:@"AirshipConfig" ofType:@"plist"]];
}

+ (UAConfig *)configWithContentsOfFile:(NSString *)path {
    UAConfig *config = [[[UAConfig alloc] init] autorelease];

    //copy from dictionary plist

    NSDictionary *configDict = [[[NSDictionary alloc] initWithContentsOfFile:path] autorelease];

    NSDictionary *normalizedDictionary = [UAConfig normalizeDictionary:configDict];

    [config setValuesForKeysWithDictionary:normalizedDictionary];


    return config;
}

#pragma mark -
#pragma Resolved values

- (NSString *)appKey {
    return self.inProduction ? self.productionAppKey : self.developmentAppKey;
}

- (NSString *)appSecret {
    return self.inProduction ? self.productionAppSecret : self.developmentAppSecret;
}

- (UALogLevel)logLevel {
    return self.inProduction ? self.productionLogLevel : self.developmentLogLevel;
}

- (BOOL)inProduction {
    return self.detectProvisioningMode ? [self usesProductionPushServer] : _inProduction;
}

#pragma mark -
#pragma Data validation
- (BOOL)validate {

    BOOL valid = YES;

    //Check the format of the app key and password.
    //If they're missing or malformed, stop takeoff
    //and prevent the app from connecting to UA.
    NSPredicate *matchPred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^\\S{22}+$"];

    if (![matchPred evaluateWithObject:self.developmentAppKey]) {
        UA_LWARN(@"Development App Key is not valid.");
    }

    if (![matchPred evaluateWithObject:self.developmentAppSecret]) {
        UA_LWARN(@"Development App Secret is not valid.");
    }

    if (![matchPred evaluateWithObject:self.productionAppKey]) {
        UA_LWARN(@"Production App Key is not valid.");
    }

    if (![matchPred evaluateWithObject:self.productionAppSecret]) {
        UA_LWARN(@"Production App Secret is not valid.");
    }

    if (![matchPred evaluateWithObject:self.appKey]) {
        UA_LERR(@"Current App Key (%@) is not valid.", self.appKey);
        valid = NO;
    }

    if (![matchPred evaluateWithObject:self.appSecret]) {
        UA_LERR(@"Current App Secret (%@) is not valid.", self.appSecret);
        valid = NO;
    }

    if (self.inProduction && self.clearKeychain) {
        UA_LERR(@"This application is in PRODUCTION and set to clear the keychain with a debug flag. ARE YOU SURE YOU WANT TO DO THIS?");
    }

    return valid;
}

+ (NSDictionary *)normalizeDictionary:(NSDictionary *)keyedValues {

    NSDictionary *oldKeyMap = @{@"LOG_LEVEL" : @"developmentLogLevel",
                                @"PRODUCTION_APP_KEY" : @"productionAppKey",
                                @"PRODUCTION_APP_SECRET" : @"productionAppSecret",
                                @"DEVELOPMENT_APP_KEY" : @"developmentAppKey",
                                @"DEVELOPMENT_APP_SECRET" : @"developmentAppSecret",
                                @"APP_STORE_OR_AD_HOC_BUILD" : @"inProduction",
                                @"DELETE_KEYCHAIN_CREDENTIALS" : @"clearKeychain",
                                @"AIRSHIP_SERVER" : @"deviceAPIURL",
                                @"ANALYTICS_SERVER" : @"analyticsURL"};

    NSMutableDictionary *newKeyedValues = [NSMutableDictionary dictionary];

    for (NSString *key in keyedValues) {
        NSString *realKey = [oldKeyMap objectForKey:key] ?: key;
        id value = [keyedValues objectForKey:key];

        // Strip whitespace, if necessary
        if ([value isKindOfClass:[NSString class]]){
            value = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        objc_property_t property = class_getProperty(self, [realKey UTF8String]);

        UA_LTRACE(@"Real key: %@", realKey);
        if (property != NULL) {
            NSString *type = [NSString stringWithUTF8String:property_getAttributes(property)];

            UA_LTRACE(@"Type: %@", type);
            if ([type hasPrefix:@"Tc"] || [type hasPrefix:@"TB"]) {//treat chars as bools
                value = [NSNumber numberWithBool:[value boolValue]];
            } else if (![type hasPrefix:@"T@"]) {//indicates an obj-c object (id)
                value = [NSNumber numberWithInt:[value intValue]];
            }
        }

        [newKeyedValues setValue:value forKey:realKey];
    }

    UA_LTRACE(@"New Dictionary: %@", [newKeyedValues description]);
    
    return newKeyedValues;
}

#pragma mark -
#pragma Provisioning Profile Detection

- (BOOL)usesProductionPushServer {

    // only test if a profile is available
    // this is useful for testing/detecting simulator
    dispatch_once(&usesProductionPred_, ^{
        if (self.profilePath) {
            usesProductionPushServer_ = [UAConfig isProductionProvisioningProfile:self.profilePath];
        } else {
            UA_LERR(@"No profile found. Unable to automatically detect provisioning mode in the simulator. Falling back to inProduction as set: %d", _inProduction);
            usesProductionPushServer_ = _inProduction;
        }
    });

    return usesProductionPushServer_;
}

+ (BOOL)isProductionProvisioningProfile:(NSString *)profilePath {

    // Attempt to read this file as ASCII (rather than UTF-8) due to the binary blocks before and after the plist data
    NSError *err = nil;
    NSString *embeddedProfile = [NSString stringWithContentsOfFile:profilePath
                                                          encoding:NSASCIIStringEncoding
                                                             error:&err];
    UA_LTRACE(@"Profile path: %@", profilePath);

    if (err) {
        UA_LERR(@"No mobile provision profile found or the profile could not be read. Defaulting to production mode.");
        return YES;
    }

    NSDictionary *plistDict = nil;
    NSScanner *scanner = [[[NSScanner alloc] initWithString:embeddedProfile] autorelease];

    if ([scanner scanUpToString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>" intoString:nil]) {
        NSString *plistString = nil;
        if ([scanner scanUpToString:@"</plist>" intoString:&plistString]) {
            NSData *data = [[plistString stringByAppendingString:@"</plist>"] dataUsingEncoding:NSUTF8StringEncoding];
            plistDict = [NSPropertyListSerialization propertyListFromData:data
                                                         mutabilityOption:NSPropertyListImmutable
                                                                   format:nil
                                                         errorDescription:nil];
            //UA_LTRACE(@"Embedded Profile Plist dict:\n%@", [plistDict description]);
        }
    }

    // Tell the logs a little about the app
    if ([plistDict valueForKeyPath:@"ProvisionedDevices"]){
        if ([[plistDict valueForKeyPath:@"Entitlements.get-task-allow"] boolValue]) {
            UA_LDEBUG(@"Debug provisioning profile. Uses the APNS Sandbox Servers.");
        } else {
            UA_LDEBUG(@"Ad-Hoc provisioning profile. Uses the APNS Production Servers.");
        }
    } else if ([[plistDict valueForKeyPath:@"ProvisionsAllDevices"] boolValue]) {
        UA_LDEBUG(@"Enterprise provisioning profile. Uses the APNS Production Servers.");
    } else {
        UA_LDEBUG(@"App Store provisioning profile. Uses the APNS Production Servers.");
    }

    NSString *apsEnvironment = [plistDict valueForKeyPath:@"Entitlements.aps-environment"];
    UA_LDEBUG(@"APS Environment set to %@", apsEnvironment);
    if ([@"development" isEqualToString:apsEnvironment]) {
        return NO;
    }

    // Let the dev know if there's not an APS entitlement in the profile. Something is terribly wrong.
    if (!apsEnvironment) {
        UA_LERR(@"aps-environment value is not set. If this is not a simulator, ensure that the app is properly provisioned for push");
    }

    return YES;// For safety, assume production unless the profile is explicitly set to development
}

- (void)setAnalyticsURL:(NSString *)analyticsURL {
    //Any appending url starts with a beginning /, so make sure the base url does not
    if ([analyticsURL hasSuffix:@"/"]) {
        UA_LWARN(@"Analytics URL ends with a trailing slash, stripping ending slash.");
        _analyticsURL = [[analyticsURL substringWithRange:NSMakeRange(0, [analyticsURL length] - 1)] retain];
    } else {
        _analyticsURL = [analyticsURL copy];
    }
}

- (void)setDeviceAPIURL:(NSString *)deviceAPIURL {
    //Any appending url starts with a beginning /, so make sure the base url does not
    if ([deviceAPIURL hasSuffix:@"/"]) {
        UA_LWARN(@"Device API URL ends with a trailing slash, stripping ending slash.");
        _deviceAPIURL = [[deviceAPIURL substringWithRange:NSMakeRange(0, [deviceAPIURL length] - 1)] retain];
    } else {
        _deviceAPIURL = [deviceAPIURL copy];
    }
}
#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid UAConfig key: %@", key);
}

@end
