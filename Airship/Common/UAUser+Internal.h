/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

// NSUserDefaultsKey for libUAirship verision >= v1.3.6
// Changing the key forces devices to update with UA at least once
// with new workflow. 
#define kLastUpdatedDeviceTokenKey @"UAUserLastUpdatedDeviceTokenKey"

// NSUserDefaultsKey for libUAirship version <= v1.3.5
// Replacing this key to ensure migration to new defaults setup post v1.3.5
#define kLastDeviceTokenKey @"UAUserLastDeviceTokenKey"

//Legacy keys for migration from pre-keychain user store
#define kLegacyInboxUserKey @"UAAirMailDefaultInboxUser"
#define kLegacyInboxPassKey @"UAAirMailDefaultInboxPass"
#define kLegacySubscriptionsUserKey @"UASubscriptionUserKey"
#define kLegacySubscriptionsPassKey @"UASubscriptionPassKey"
#define kLegacySubscriptionsEmailKey @"UASubscriptionEmail"

//Legacy keys from Inbox
#define kLegacyInboxAliasKey @"UAAirMailDefaultInboxAlias"
#define kLegacyInboxTagsKey @"UAAirMailDefaultInboxTags"

//Current dictionary keys

#define kUserRecoveryKey @"UAUserRecoveryKey"
#define kUserRecoveryStatusURL @"UAUserRecoveryStatusURL"
#define kAlreadySentUserRecoveryEmail @"UAUserRecoveryKeySent"
#define kRecoveryEmail @"UAUserRecoveryEmail"
#define kTagsKey @"UAUserTagsKey"
#define kAliasKey @"UAUserAliasKey"
#define kUserUrlKey @"UAUserUrlKey"

@interface UAUser()
@property (nonatomic, assign) BOOL deviceTokenHasChanged;
@property (nonatomic, copy) NSString *deviceToken;

// Migrate user from user defaults to keychain
- (void)migrateUser;

//Device Token Change Listener
- (void)listenForDeviceTokenReg;
- (void)cancelListeningForDeviceToken;
- (void)updateDefaultDeviceToken;

//User retrieval
- (void)retrieveRequestSucceeded:(UA_ASIHTTPRequest*)request;
- (void)retrieveRequestFailed:(UA_ASIHTTPRequest*)request;

//User creation
- (void)userCreationDidFail:(UA_ASIHTTPRequest *)request;

@end

