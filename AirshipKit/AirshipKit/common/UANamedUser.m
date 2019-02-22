/* Copyright Urban Airship and Contributors */

#import "UANamedUser+Internal.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAPush+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagUtils+Internal.h"
#import "UAConfig+Internal.h"

#define kUAMaxNamedUserIDLength 128

NSString *const UANamedUserIDKey = @"UANamedUserID";
NSString *const UANamedUserChangeTokenKey = @"UANamedUserChangeToken";
NSString *const UANamedUserLastUpdatedTokenKey = @"UANamedUserLastUpdatedToken";

@interface UANamedUser()

/**
 * The UATagGroupsRegistrar that manages tag group registration with Urban Airship.
 */
@property (nonatomic, strong) UATagGroupsRegistrar *tagGroupsRegistrar;

@end

@implementation UANamedUser

- (instancetype)initWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.config = config;
        self.push = push;
        self.dataStore = dataStore;
        self.namedUserAPIClient = [UANamedUserAPIClient clientWithConfig:config];
        self.namedUserAPIClient.enabled = self.componentEnabled;
        self.tagGroupsRegistrar = tagGroupsRegistrar;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(channelCreated:)
                                                     name:UAChannelCreatedEvent
                                                   object:nil];

        // Update the named user if necessary.
        [self update];
    }

    return self;
}

+ (instancetype) namedUserWithPush:(UAPush *)push
                            config:(UAConfig *)config
                         dataStore:(UAPreferenceDataStore *)dataStore
                tagGroupsRegistrar:(nonnull UATagGroupsRegistrar *)tagGroupsRegistrar  {
    return [[UANamedUser alloc] initWithPush:push config:config dataStore:dataStore tagGroupsRegistrar:tagGroupsRegistrar];
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

        // Update named user.
        [self update];

        // Clear pending tag group mutations
        [self.tagGroupsRegistrar clearAllPendingTagUpdates:UATagGroupsTypeNamedUser];
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
    UA_LTRACE(@"NamedUser - force named user update.");
    self.changeToken = [NSUUID UUID].UUIDString;
    [self update];
}


- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self.tagGroupsRegistrar addTags:tags group:tagGroupID type:UATagGroupsTypeNamedUser];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self.tagGroupsRegistrar removeTags:tags group:tagGroupID type:UATagGroupsTypeNamedUser];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self.tagGroupsRegistrar setTags:tags group:tagGroupID type:UATagGroupsTypeNamedUser];
}

- (void)updateTags {
    if (!self.identifier) {
        UA_LERR(@"Can't update tags without first setting a named user identifier.");
        return;
    }
    
    [self.tagGroupsRegistrar updateTagGroupsForID:self.identifier type:UATagGroupsTypeNamedUser];
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

- (void)onComponentEnableChange {
    // Disable/enable the API client and user to disable/enable the inbox
    self.namedUserAPIClient.enabled = self.componentEnabled;
    self.tagGroupsRegistrar.componentEnabled = self.componentEnabled;
}

@end
