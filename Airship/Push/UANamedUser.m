/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UANamedUser+Internal.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore.h"
#import "UANamedUserAPIClient.h"
#import "UAPush+Internal.h"

#define kUAMaxNamedUserIdLength 128

NSString *const UANamedUserIdKey = @"UANamedUserId";
NSString *const UANamedUserChangeTokenKey = @"UANamedUserChangeToken";
NSString *const UANamedUserLastUpdatedTokenKey = @"UANamedUserLastUpdatedToken";



@implementation UANamedUser

- (UAPreferenceDataStore *)dataStore {
    if (![UAirship shared].dataStore) {
        UA_LERR(@"Data store is empty, takeoff not called!");
    }
    return [UAirship shared].dataStore;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.namedUserAPIClient = [[UANamedUserAPIClient alloc] init];
    }
    return self;
}

- (void)setup {
    if (self.changeToken == nil && self.lastUpdatedToken  == nil) {
        // Skip since no one has set the named user ID. Usually from a new or re-install.
        UA_LDEBUG(@"New or re-install, skipping named user update");
        return;
    }

    if (self.changeToken != nil && [self.changeToken isEqualToString:self.lastUpdatedToken]) {
        // Skip since no change has occurred (token remain the same).
        UA_LDEBUG(@"Named user already updated. Skipping.");
        return;
    }

    if (self.identifier == nil) {
        // When identifier is nil, disassociate the current named user ID.
        [self disassociateNamedUser];
    } else {
        // When identifier is non-null, associate the currentId.
        [self associateNamedUser:self.identifier];
    }
}

- (NSString *)identifier {
    return [self.dataStore objectForKey:UANamedUserIdKey];
}

- (void)setIdentifier:(NSString *)identifier {
    NSString * trimmedId = nil;
    if (identifier != nil) {
        trimmedId = [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([trimmedId length] <= 0 || [trimmedId length] > kUAMaxNamedUserIdLength) {
            UA_LERR(@"Failed to set named user ID. The named user ID must be greater than 0 and less than 129 characters.");
            return;
        }
    }

    // check if the newly trimmed ID matches with currently stored ID
    BOOL isEqual = self.identifier == nil ? trimmedId == nil : [self.identifier isEqualToString:trimmedId];

    // if the IDs don't match or ID is set to nil and current token is nil (re-install case), then update.
    if (!isEqual || (self.identifier == nil && self.changeToken == nil)) {
        [self.dataStore setObject:trimmedId forKey:UANamedUserIdKey];

        // Update the change token.
        [self setChangeToken];

        if (self.identifier == nil) {
            // When identifier is nil, disassociate the current named user ID.
            [self disassociateNamedUser];
        } else {
            // When identifier is non-null, associate the currentId.
            [self associateNamedUser:trimmedId];
        }
    } else {
        UA_LDEBUG(@"NamedUser - Skipping update. Named user ID trimmed already matches existing named user: %@", self.identifier);
    }
}

- (void)setChangeToken {
    [self.dataStore setObject:[NSUUID UUID].UUIDString forKey:UANamedUserChangeTokenKey];
}

- (NSString *)changeToken {
    return [self.dataStore objectForKey:UANamedUserChangeTokenKey];
}

- (void)setLastUpdatedToken:(NSString *)token {
    [self.dataStore setObject:token forKey:UANamedUserLastUpdatedTokenKey];
}

- (NSString *)lastUpdatedToken {
    return [self.dataStore objectForKey:UANamedUserLastUpdatedTokenKey];
}

- (void)associateNamedUser:(NSString *)identifier {
    [self.namedUserAPIClient associate:identifier channelID:[UAPush shared].channelID
     onSuccess:^{
         [self setLastUpdatedToken:self.changeToken];
         UA_LINFO(@"Named user associated to channel successfully.");
     }
     onFailure:^(UAHTTPRequest *request) {
         UA_LDEBUG(@"Failed to associate channel to named user.");
     }];
}

- (void)disassociateNamedUser {
    [self.namedUserAPIClient disassociate:[UAPush shared].channelID
     onSuccess:^{
         [self setLastUpdatedToken:self.changeToken];
         UA_LINFO(@"Named user disassociated from channel successfully.");
     }
     onFailure:^(UAHTTPRequest *request) {
         UA_LDEBUG(@"Failed to disassociate channel from named user.");
     }];
}

@end
