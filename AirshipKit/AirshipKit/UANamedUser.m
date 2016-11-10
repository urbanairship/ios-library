/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UANamedUser+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAPush+Internal.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagUtils.h"
#import "UAHTTPConnection+Internal.h"
#import "UAConfig+Internal.h"

#define kUAMaxNamedUserIDLength 128

NSString *const UANamedUserIDKey = @"UANamedUserID";
NSString *const UANamedUserChangeTokenKey = @"UANamedUserChangeToken";
NSString *const UANamedUserLastUpdatedTokenKey = @"UANamedUserLastUpdatedToken";

// Named user tag group keys
NSString *const UANamedUserAddTagGroupsSettingsKey = @"UANamedUserAddTagGroups";
NSString *const UANamedUserRemoveTagGroupsSettingsKey = @"UANamedUserRemoveTagGroups";

@implementation UANamedUser

- (instancetype)initWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];
    if (self) {
        self.config = config;
        self.push = push;
        self.dataStore = dataStore;
        self.namedUserAPIClient = [UANamedUserAPIClient clientWithConfig:config];
        self.tagGroupsAPIClient = [UATagGroupsAPIClient clientWithConfig:config];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(channelCreated:)
                                                     name:UAChannelCreatedEvent
                                                   object:nil];


        // Update the named user if necessary.
        [self update];
    }
    
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


+(instancetype) namedUserWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UANamedUser alloc] initWithPush:push config:config dataStore:dataStore];
}

- (void)update {
    if (!self.changeToken && !self.lastUpdatedToken) {
        // Skip since no one has set the named user ID. Usually from a new or re-install.
        UA_LDEBUG(@"New or re-install, skipping named user update.");
        return;
    }

    if ([self.changeToken isEqualToString:self.lastUpdatedToken]) {
        // Skip since no change has occurred (token remains the same).
        UA_LDEBUG(@"Named user already updated. Skipping.");
        return;
    }

    if (!self.push.channelID) {
        // Skip since we don't have a channel ID.
        UA_LDEBUG(@"The channel ID does not exist. Will retry when channel ID is available.");
        return;
    }

    if (self.identifier) {
        // When identifier is non-nil, associate the current named user ID.
        [self associateNamedUser];
    } else {
        // When identifier is nil, disassociate the current named user ID.
        [self disassociateNamedUser];
    }
}

- (NSString *)identifier {
    return [self.dataStore objectForKey:UANamedUserIDKey];
}

- (void)setIdentifier:(NSString *)identifier {
    NSString *trimmedID;
    if (identifier) {
        trimmedID = [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([trimmedID length] <= 0 || [trimmedID length] > kUAMaxNamedUserIDLength) {
            UA_LERR(@"Failed to set named user ID. The named user ID must be greater than 0 and less than 129 characters.");
            return;
        }
    }

    // if the IDs don't match or ID is set to nil and current token is nil (re-install case), then update.
    if (!(self.identifier == trimmedID || [self.identifier isEqualToString:trimmedID]) || (!self.identifier && !self.changeToken)) {
        [self.dataStore setValue:trimmedID forKey:UANamedUserIDKey];

        // Update the change token.
        self.changeToken = [NSUUID UUID].UUIDString;

        // When named user ID change, clear pending named user tags.
        self.pendingAddTags = nil;
        self.pendingRemoveTags = nil;

        // Update named user.
        [self update];

    } else {
        UA_LDEBUG(@"NamedUser - Skipping update. Named user ID trimmed already matches existing named user: %@", self.identifier);
    }
}

- (void)setChangeToken:(NSString *)uuidString {
    [self.dataStore setValue:uuidString forKey:UANamedUserChangeTokenKey];
}

- (NSString *)changeToken {
    return [self.dataStore objectForKey:UANamedUserChangeTokenKey];
}

- (void)setLastUpdatedToken:(NSString *)token {
    [self.dataStore setValue:token forKey:UANamedUserLastUpdatedTokenKey];
}

- (NSString *)lastUpdatedToken {
    return [self.dataStore objectForKey:UANamedUserLastUpdatedTokenKey];
}

- (NSDictionary *)pendingAddTags {
    return [self.dataStore objectForKey:UANamedUserAddTagGroupsSettingsKey];
}

- (void)setPendingAddTags:(NSDictionary *)addTagGroups {
    [self.dataStore setObject:addTagGroups forKey:UANamedUserAddTagGroupsSettingsKey];
}

- (NSDictionary *)pendingRemoveTags {
    return [self.dataStore objectForKey:UANamedUserRemoveTagGroupsSettingsKey];
}

- (void)setPendingRemoveTags:(NSDictionary *)removeTagGroups {
    [self.dataStore setObject:removeTagGroups forKey:UANamedUserRemoveTagGroupsSettingsKey];
}

- (void)associateNamedUser {
    NSString *token = self.changeToken;
    [self.namedUserAPIClient associate:self.identifier channelID:self.push.channelID
     onSuccess:^{
         self.lastUpdatedToken = token;
         UA_LDEBUG(@"Named user associated to channel successfully.");
     }
     onFailure:^(NSUInteger status) {
         UA_LDEBUG(@"Failed to associate channel to named user.");
     }];
}

- (void)disassociateNamedUser {
    NSString *token = self.changeToken;
    [self.namedUserAPIClient disassociate:self.push.channelID
     onSuccess:^{
         self.lastUpdatedToken = token;
         UA_LDEBUG(@"Named user disassociated from channel successfully.");
     }
     onFailure:^(NSUInteger status) {
         UA_LDEBUG(@"Failed to disassociate channel from named user.");
     }];
}

- (void)disassociateNamedUserIfNil {
    if (!self.identifier) {
        self.identifier = nil;
    }
}

- (void)forceUpdate {
    UA_LDEBUG(@"NamedUser - force named user update.");
    self.changeToken = [NSUUID UUID].UUIDString;
    [self update];
}

- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {

    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];

    if (![UATagUtils isValid:normalizedTags group:tagGroupID]) {
        return;
    }

    // Check if remove tags contain any tags to add.
    [self setPendingRemoveTags:[UATagUtils removePendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingRemoveTags]];

    // Combine the tags to be added with pendingAddTags.
    [self setPendingAddTags:[UATagUtils addPendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingAddTags]];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {

    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];

    if (![UATagUtils isValid:normalizedTags group:tagGroupID]) {
        return;
    }

    // Check if add tags contain any tags to be removed.
    [self setPendingAddTags:[UATagUtils removePendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingAddTags]];

    // Combine the tags to be removed with pendingRemoveTags.
    [self setPendingRemoveTags:[UATagUtils addPendingTags:normalizedTags group:tagGroupID pendingTagsDictionary:self.pendingRemoveTags]];
}

- (void)resetPendingTagsWithAddTags:(NSMutableDictionary *)addTags removeTags:(NSMutableDictionary *)removeTags {
    // If there are new pendingRemoveTags since last request,
    // check if addTags contain any tags to be removed.
    if (self.pendingRemoveTags.count) {
        for (NSString *group in self.pendingRemoveTags) {
            if (group && addTags[group]) {
                NSArray *pendingRemoveTagsArray = [NSArray arrayWithArray:self.pendingRemoveTags[group]];
                [addTags removeObjectsForKeys:pendingRemoveTagsArray];
            }
        }
    }

    // If there are new pendingAddTags since last request,
    // check if removeTags contain any tags to add.
    if (self.pendingAddTags.count) {
        for (NSString *group in self.pendingAddTags) {
            if (group && removeTags[group]) {
                NSArray *pendingAddTagsArray = [NSArray arrayWithArray:self.pendingAddTags[group]];
                [removeTags removeObjectsForKeys:pendingAddTagsArray];
            }
        }
    }

    // If there are new pendingRemoveTags since last request,
    // combine the new pendingRemoveTags with removeTags.
    if (self.pendingRemoveTags.count) {
        [removeTags addEntriesFromDictionary:self.pendingRemoveTags];
    }

    // If there are new pendingAddTags since last request,
    // combine the new pendingAddTags with addTags.
    if (self.pendingAddTags.count) {
        [addTags addEntriesFromDictionary:self.pendingAddTags];
    }

    // Set self.pendingAddTags as addTags
    self.pendingAddTags = addTags;

    // Set self.pendingRemoveTags as removeTags
    self.pendingRemoveTags = removeTags;
}

- (void)updateTags {
    if (!self.pendingAddTags.count && !self.pendingRemoveTags.count) {
        return;
    }

    // Get a copy of the current add and remove pending tags
    NSMutableDictionary *addTags = [self.pendingAddTags mutableCopy];
    NSMutableDictionary *removeTags = [self.pendingRemoveTags mutableCopy];

    // On failure or background task expiration we need to reset the pending tags
    void (^resetPendingTags)() = ^{
        [self resetPendingTagsWithAddTags:addTags removeTags:removeTags];
    };

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        UA_LTRACE(@"NamedUser background task expired.");
        if (resetPendingTags) {
            resetPendingTags();
        }
        @synchronized(self) {
            [self.tagGroupsAPIClient cancelAllRequests];
        }
        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        UA_LTRACE("Background task unavailable, skipping named user tags update.");
        return;
    }

    // Clear the add and remove pending tags
    self.pendingAddTags = nil;
    self.pendingRemoveTags = nil;

    UATagGroupsAPIClientSuccessBlock successBlock = ^{
        // End background task
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    UATagGroupsAPIClientFailureBlock failureBlock = ^(NSUInteger status) {
        if (status != 400 && status != 403) {
            resetPendingTags();
        }

        // End background task
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        backgroundTask = UIBackgroundTaskInvalid;
    };

    [self.tagGroupsAPIClient updateNamedUserTags:self.identifier
                                             add:addTags
                                          remove:removeTags
                                       onSuccess:successBlock
                                       onFailure:failureBlock];
}

- (void)channelCreated:(NSNotification *)notification {
    BOOL existing = [notification.userInfo[UAChannelCreatedEventExistingKey] boolValue];

    // If this channel previously existed, a named user may be associated to it.
    if (existing && self.config.clearNamedUserOnAppRestore) {
        [self disassociateNamedUserIfNil];
    } else {
        // Once we get a channel, update the named user if necessary.
        [self update];
    }
}


@end
