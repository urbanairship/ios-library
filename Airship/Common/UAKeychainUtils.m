/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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
#import <Security/Security.h>

@interface UAKeychainUtils()
+ (NSMutableDictionary *)newSearchDictionary:(NSString *)identifier;
@end
	

@implementation UAKeychainUtils

+ (BOOL)createKeychainValueForUsername:(NSString *)username withPassword:(NSString *)password forIdentifier:(NSString *)identifier {
	
	//UALOG(@"Storing Username: %@ and Password: %@", username, password);
	
    NSMutableDictionary *dictionary = [UAKeychainUtils newSearchDictionary:identifier];
	
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
                      withEmailAddress:(NSString *)emailAddress
                         forIdentifier:(NSString *)identifier {
	
	//setup search dict, use username as query param
    NSMutableDictionary *searchDictionary = [self newSearchDictionary:identifier];
	[searchDictionary setObject:username forKey:(id)kSecAttrAccount];
	
	//update password
    NSMutableDictionary *updateDictionary = [[NSMutableDictionary alloc] init];
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    [updateDictionary setObject:passwordData forKey:(id)kSecValueData];
    
    //update email
    if (emailAddress != nil) {
        [updateDictionary setObject:emailAddress forKey:(id)kSecAttrLabel];
    }
    
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

+ (NSString *)getEmailAddress:(NSString *)identifier {
    NSMutableDictionary *attributeSearch = [UAKeychainUtils newSearchDictionary:identifier];
	
    // Add search attributes
    [attributeSearch setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
	
    // Add search return types
    [attributeSearch setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	
	//Get username first
    NSMutableDictionary *attributeResult = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)attributeSearch,
                                          (CFTypeRef *)&attributeResult);
	
	NSString *emailAddress = nil;
	if (status == errSecSuccess) {
		NSString* labelValue = [attributeResult objectForKey:(id)kSecAttrLabel];
		if (labelValue) {
			emailAddress = [[labelValue mutableCopy] autorelease];
			//UALOG(@"Loaded Email Address: %@", emailAddress);
		}
	}
	[attributeResult release];
	[attributeSearch release];
	
	return emailAddress;
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

@end
