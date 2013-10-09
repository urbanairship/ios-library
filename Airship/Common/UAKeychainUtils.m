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

static NSString *_cachedDeviceID = nil;

@interface UAKeychainUtils()
+ (NSMutableDictionary *)searchDictionaryWithIdentifier:(NSString *)identifier;

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

    NSMutableDictionary *userDictionary = [UAKeychainUtils searchDictionaryWithIdentifier:identifier];

    //set access permission - we use the keychain for it's stickiness, not security,
    //so the least permissive setting is acceptable here
    [userDictionary setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];

    //set username data
    [userDictionary setObject:username forKey:(__bridge id)kSecAttrAccount];

    //set password data
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [userDictionary setObject:passwordData forKey:(__bridge id)kSecValueData];

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)userDictionary, NULL);

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}

+ (void)deleteKeychainValue:(NSString *)identifier {
    NSMutableDictionary *searchDictionary = [UAKeychainUtils searchDictionaryWithIdentifier:identifier];
    SecItemDelete((__bridge CFDictionaryRef)searchDictionary);
}

+ (BOOL)updateKeychainValueForUsername:(NSString *)username 
                          withPassword:(NSString *)password 
                         forIdentifier:(NSString *)identifier {

    //setup search dict, use username as query param
    NSMutableDictionary *searchDictionary = [self searchDictionaryWithIdentifier:identifier];
    [searchDictionary setObject:username forKey:(__bridge id)kSecAttrAccount];

    //update password
    NSMutableDictionary *updateDictionary = [NSMutableDictionary dictionary];
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [updateDictionary setObject:passwordData forKey:(__bridge id)kSecValueData];

    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)searchDictionary,
                                    (__bridge CFDictionaryRef)updateDictionary);

    if (status == errSecSuccess) {
        return YES;
    }
    return NO;
}


+ (NSString *)getPassword:(NSString *)identifier {

    if (!identifier) {
        UA_LERR(@"Unable to get password. The identifier for the keychain is nil.");
        return nil;
    }

    // Get password next
    NSMutableDictionary *passwordSearch = [UAKeychainUtils searchDictionaryWithIdentifier:identifier];

    // Add search attributes
    [passwordSearch setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    // Add search return types
    [passwordSearch setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];

    CFDataRef passwordDataRef = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordSearch,
                                          (CFTypeRef *)&passwordDataRef);
    NSData *passwordData = (__bridge_transfer NSData *)passwordDataRef;

    NSString *password = nil;
    if (status == errSecSuccess) {
        if (passwordData) {
            password = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
            //UALOG(@"Loaded Password: %@",password);
        }
    }

    return password;
}

+ (NSString *)getUsername:(NSString *)identifier {

    if (!identifier) {
        UA_LERR(@"Unable to get username. The identifier for the keychain is nil.");
        return nil;
    }

    NSMutableDictionary *attributeSearch = [UAKeychainUtils searchDictionaryWithIdentifier:identifier];

    // Add search attributes
    [attributeSearch setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    // Add search return types
    [attributeSearch setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];

    // Get username first
    CFDictionaryRef resultDataRef = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attributeSearch,
                                          (CFTypeRef *)&resultDataRef);

    NSDictionary *resultDict = (__bridge_transfer NSDictionary *)resultDataRef;

    NSString *username = nil;
    if (status == errSecSuccess) {
        NSString *accountValue = [resultDict objectForKey:(__bridge id)kSecAttrAccount];
        if (accountValue) {
            username = [accountValue mutableCopy];
            //UALOG(@"Loaded Username: %@",username);
        }
    }

	return username;
}

+ (NSMutableDictionary *)searchDictionaryWithIdentifier:(NSString *)identifier {
    NSMutableDictionary *searchDictionary = [NSMutableDictionary dictionary];

    [searchDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];

    //use identifier param and the bundle ID as keys
    NSData *encodedIdentifier = [identifier dataUsingEncoding:NSUTF8StringEncoding];
    [searchDictionary setObject:encodedIdentifier forKey:(__bridge id)kSecAttrGeneric];

    NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    [searchDictionary setObject:bundleId forKey:(__bridge id)kSecAttrService];

    return searchDictionary; 
}

#pragma mark -
#pragma UA Device ID

+ (NSString *)createDeviceID {
    //UALOG(@"Storing Username: %@ and Password: %@", username, password);

    NSString *deviceID = [UAUtils UUID];

    NSMutableDictionary *keychainValues = [UAKeychainUtils searchDictionaryWithIdentifier:kUAKeychainDeviceIDKey];

    //set access permission - we use the keychain for its stickiness, not security,
    //so the least permissive setting is acceptable here
    [keychainValues setObject:(__bridge id)kSecAttrAccessibleAlways forKey:(__bridge id)kSecAttrAccessible];

    //set model name (username) data
    [keychainValues setObject:[UAUtils deviceModelName] forKey:(__bridge id)kSecAttrAccount];

    //set device id (password) data
    NSData *deviceIdData = [deviceID dataUsingEncoding:NSUTF8StringEncoding];
    [keychainValues setObject:deviceIdData forKey:(__bridge id)kSecValueData];

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)keychainValues, NULL);

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
    NSMutableDictionary *deviceIDQuery = [UAKeychainUtils searchDictionaryWithIdentifier:kUAKeychainDeviceIDKey];

    // Add search attributes
    [deviceIDQuery setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    // Add search return types
    [deviceIDQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [deviceIDQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];

    CFDictionaryRef resultDataRef = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)deviceIDQuery, (CFTypeRef *)&resultDataRef);

    NSDictionary *resultDict = (__bridge_transfer NSDictionary *)resultDataRef;

    NSString *deviceID = nil;
    NSString *modelName = nil;
    if (status == errSecSuccess) {

        UALOG(@"Retrieved device id info from keychain.");

        if (resultDataRef) {
            //grab the deviceId and associated model name
            deviceID = [[NSString alloc] initWithData:[resultDict valueForKey:(__bridge id)kSecValueData] encoding:NSUTF8StringEncoding];
            modelName = [[resultDict objectForKey:(__bridge id)kSecAttrAccount] mutableCopy];

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

    _cachedDeviceID = [deviceID copy];

    return deviceID;
}

@end
