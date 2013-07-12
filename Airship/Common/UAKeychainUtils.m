/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "UAKeychainUtils.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAUtils.h"

#import <Security/Security.h>

static NSString* _cachedDeviceID = nil;

@interface UAKeychainUtils()
+ (NSMutableDictionary *)newSearchDictionary:(NSString *)identifier;

/**
 * Creates a new UA Device ID (UUID) and stores it in the keychain.
 *
 * @return The device ID.
 */
+ (NSString *)createDeviceID;
@end


@implementation UAKeychainUtils

+ (BOOL)createKeychainValueForUsername:(NSString *)username withPassword:(NSString *)password forIdentifier:(NSString *)identifier {

    //UALOG(@"Storing Username: %@ and Password: %@", username, password);

    NSMutableDictionary *dictionary = [UAKeychainUtils newSearchDictionary:identifier];

    //set access permission - we use the keychain for it's stickiness, not security,
    //so the least permissive setting is acceptable here
   [dictionary setObject:(id)kSecAttrAccessibleAlways forKey:(id)kSecAttrAccessible];

    //set username data
    [dictionary setObject:username forKey:(id)kSecAttrAccount];

    //set password data
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [dictionary setObject:passwordData forKey:(id)kSecValueData];

    OSStatus status = SecItemAdd((CFDictionaryRef)dictionary, NULL);
    [dictionary release];

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}

+ (void)deleteKeychainValue:(NSString *)identifier {

    NSMutableDictionary *searchDictionary = [UAKeychainUtils newSearchDictionary:identifier];
    SecItemDelete((CFDictionaryRef)searchDictionary);
    [searchDictionary release];
}

+ (BOOL)updateKeychainValueForUsername:(NSString *)username 
                          withPassword:(NSString *)password 
                         forIdentifier:(NSString *)identifier {

    //setup search dict, use username as query param
    NSMutableDictionary *searchDictionary = [self newSearchDictionary:identifier];
    [searchDictionary setObject:username forKey:(id)kSecAttrAccount];

    //update password
    NSMutableDictionary *updateDictionary = [[NSMutableDictionary alloc] init];
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [updateDictionary setObject:passwordData forKey:(id)kSecValueData];


    OSStatus status = SecItemUpdate((CFDictionaryRef)searchDictionary,
                                    (CFDictionaryRef)updateDictionary);

    [searchDictionary release];
    [updateDictionary release];

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}


+ (NSString *)getPassword:(NSString *)identifier {

    //Get password next
    NSMutableDictionary *passwordSearch = [UAKeychainUtils newSearchDictionary:identifier];

    // Add search attributes
    [passwordSearch setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    // Add search return types
    [passwordSearch setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];

    NSData *passwordData = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)passwordSearch,
                                          (CFTypeRef *)&passwordData);
    [passwordSearch release];

    NSString *password = nil;
    if (status == errSecSuccess) {
        if (passwordData) {
            password = [[[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding] autorelease];
            [passwordData release];
            passwordData = nil;

            //UALOG(@"Loaded Password: %@",password);
        }
    }

    return password;
}

+ (NSString *)getUsername:(NSString *)identifier {
    NSMutableDictionary *attributeSearch = [UAKeychainUtils newSearchDictionary:identifier];

    // Add search attributes
    [attributeSearch setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    // Add search return types
    [attributeSearch setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];

    //Get username first
    NSMutableDictionary *attributeResult = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)attributeSearch,
                                          (CFTypeRef *)&attributeResult);

    NSString *username = nil;
    if (status == errSecSuccess) {
        NSString* accountValue = [attributeResult objectForKey:(id)kSecAttrAccount];
        if (accountValue) {
            username = [[accountValue mutableCopy] autorelease];
            //UALOG(@"Loaded Username: %@",username);
        }
    }
    [attributeResult release];
    [attributeSearch release];

    return username;
}

+ (NSMutableDictionary *)newSearchDictionary:(NSString *)identifier {
    NSMutableDictionary *searchDictionary = [[NSMutableDictionary alloc] init];  

    [searchDictionary setObject:(id)kSecClassGenericPassword forKey:(id)kSecClass];

    //use identifier param and the bundle ID as keys
    NSData *encodedIdentifier = [identifier dataUsingEncoding:NSUTF8StringEncoding];
    [searchDictionary setObject:encodedIdentifier forKey:(id)kSecAttrGeneric];

    NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    [searchDictionary setObject:bundleId forKey:(id)kSecAttrService];

    return searchDictionary; 
}

#pragma mark -
#pragma UA Device ID

+ (NSString *)createDeviceID {
    //UALOG(@"Storing Username: %@ and Password: %@", username, password);

    NSString *deviceID = [UAUtils UUID];

    NSMutableDictionary *keychainValues = [UAKeychainUtils newSearchDictionary:kUAKeychainDeviceIDKey];

    //set access permission - we use the keychain for it's stickiness, not security,
    //so the least permissive setting is acceptable here
    [keychainValues setObject:(id)kSecAttrAccessibleAlways forKey:(id)kSecAttrAccessible];

    //set model name (username) data
    [keychainValues setObject:[UAUtils deviceModelName] forKey:(id)kSecAttrAccount];

    //set device id (password) data
    NSData *deviceIdData = [deviceID dataUsingEncoding:NSUTF8StringEncoding];
    [keychainValues setObject:deviceIdData forKey:(id)kSecValueData];

    OSStatus status = SecItemAdd((CFDictionaryRef)keychainValues, NULL);
    [keychainValues release];

    if (status == errSecSuccess) {
        return deviceID;
    } else {
        return @"";
    }
}

+ (NSString *)getDeviceID {

    if (_cachedDeviceID) {
        return _cachedDeviceID;
    }

    //Get password next
    NSMutableDictionary *deviceIDQuery = [[UAKeychainUtils newSearchDictionary:kUAKeychainDeviceIDKey] autorelease];

    // Add search attributes
    [deviceIDQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    // Add search return types
    [deviceIDQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [deviceIDQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];

    NSDictionary *result;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)deviceIDQuery, (CFTypeRef *)&result);

    NSString *deviceID = nil;
    NSString *modelName = nil;
    if (status == errSecSuccess) {

        UALOG(@"Retrieved device id info from keychain.");

        if (result) {
            //grab the deviceId and associated model name
            deviceID = [[[NSString alloc] initWithData:[result valueForKey:(id)kSecValueData] encoding:NSUTF8StringEncoding] autorelease];
            modelName = [[[result objectForKey:(id)kSecAttrAccount] mutableCopy] autorelease];

            [result release];
            result = nil;

            UALOG(@"Loaded Device ID: %@", deviceID);
            UALOG(@"Loaded Model Name: %@", modelName);
        } else {
            UALOG(@"Device ID result is nil.");
        }
    }

    // If the stored deviceID is nil (it has never been set) or the stored the model name is not
    // equal to the current device's model name, generate a new ID
    //
    // The device ID is reset on a hardware change so that we have a device-unique ID. The UAUser ID
    // will be migrated in the case of a device upgrade, so we will be able to maintain continuity
    // and a history of devices per user.
    if (!deviceID || ![modelName isEqualToString:[UAUtils deviceModelName]]) {
        UALOG(@"Device model changed. Regenerating the device ID.");
        [UAKeychainUtils deleteKeychainValue:kUAKeychainDeviceIDKey];
        deviceID = [UAKeychainUtils createDeviceID];
        UALOG(@"New device ID: %@", deviceID);
    }

    [_cachedDeviceID release];
    _cachedDeviceID = [deviceID copy];

    return deviceID;
}

@end
