/* Copyright Airship and Contributors */

#import "UANamedUser+Internal.h"
#import "UANamedUserAPIClient+Internal.h"
#import "UAChannel.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagUtils+Internal.h"
#import "UARuntimeConfig.h"

#define kUAMaxNamedUserIDLength 128

NSString *const UANamedUserIDKey = @"UANamedUserID";
NSString *const UANamedUserChangeTokenKey = @"UANamedUserChangeToken";
NSString *const UANamedUserLastUpdatedTokenKey = @"UANamedUserLastUpdatedToken";
NSString *const UANamedUserLastChannelIDKey = @"UANamedUserLastChannelID";

@interface UANamedUser()

/**
 * The UATagGroupsRegistrar that manages tag group registration with Airship.
 */
@property (nonatomic, strong) UATagGroupsRegistrar *tagGroupsRegistrar;
@property (nonatomic, copy) NSString *lastChannelID;

@end

@implementation UANamedUser

- (instancetype)initWithChannel:(UAChannel *)channel config:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.config = config;
        self.channel = channel;
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

+ (instancetype) namedUserWithChannel:(UAChannel *)channel
                            config:(UARuntimeConfig *)config
                         dataStore:(UAPreferenceDataStore *)dataStore
                tagGroupsRegistrar:(nonnull UATagGroupsRegistrar *)tagGroupsRegistrar  {
    return [[UANamedUser alloc] initWithChannel:channel config:config dataStore:dataStore tagGroupsRegistrar:tagGroupsRegistrar];
}

- (void)update {
    if (!self.changeToken && !self.lastUpdatedToken) {
        // Skip since no one has set the named user ID. Usually from a new or re-install.
        UA_LDEBUG(@"New or re-install, skipping named user update.");
        return;
    }

    if ([self.lastChannelID isEqualToString:self.channel.identifier] && [self.changeToken isEqualToString:self.lastUpdatedToken]) {
        // Skip since no change has occurred (token remains the same).
        UA_LDEBUG(@"Named user already updated. Skipping.");
        return;
    }

    if (!self.channel.identifier) {
        // Skip since we don't have a channel ID.
        UA_LDEBUG(@"The channel ID does not exist. Will retry when channel ID is available.");
        return;
    }

    // Treat a nil or empty string as a command to disassociate the named user
    if (self.identifier && [self.identifier length] != 0) {
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
    if (identifier && !self.isDataCollectionEnabled) {
        UA_LWARN(@"Ignoring named user ID request, global data collection is disabled");
        return;
    }
    
    NSString *trimmedID;

    // Treat a nil or empty string as a command to disassociate the named user
    if (identifier && [identifier length] != 0) {
        trimmedID = [identifier stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // Treat post-trim empty string and string exceeding max chars as invalid
        if ([trimmedID length] <= 0 || [trimmedID length] > kUAMaxNamedUserIDLength) {
            UA_LERR(@"Failed to set named user ID. The named user ID must be composed of non-whitespace characters and be less than 129 characters in length.");
            return;
        }
    }

    BOOL identifierHasChanged = self.identifier != trimmedID && ![self.identifier isEqualToString:trimmedID];

    BOOL reinstallCase = (!self.identifier && !self.changeToken);

    if (identifierHasChanged || reinstallCase) {
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

- (void)setLastChannelID:(NSString *)lastChannelID {
    [self.dataStore setValue:lastChannelID forKey:UANamedUserLastChannelIDKey];
}

- (NSString *)lastChannelID {
    return [self.dataStore objectForKey:UANamedUserLastChannelIDKey];
}

- (void)associateNamedUser {
    NSString *token = self.changeToken;
    NSString *channelID = self.channel.identifier;
    [self.namedUserAPIClient associate:self.identifier channelID:channelID onSuccess:^{
        self.lastUpdatedToken = token;
        self.lastChannelID = channelID;
        UA_LDEBUG(@"Named user associated to channel successfully.");
    } onFailure:^(NSUInteger status) {
        UA_LDEBUG(@"Failed to associate channel to named user.");
    }];
}

- (void)disassociateNamedUser {
    NSString *token = self.changeToken;
    NSString *channelID = self.channel.identifier;
    [self.namedUserAPIClient disassociate:channelID onSuccess:^{
        self.lastUpdatedToken = token;
        self.lastChannelID = channelID;
        UA_LDEBUG(@"Named user disassociated from channel successfully.");
    } onFailure:^(NSUInteger status) {
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
    if (!self.isDataCollectionEnabled) {
        UA_LWARN(@"Unable to add tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

    [self.tagGroupsRegistrar addTags:tags group:tagGroupID type:UATagGroupsTypeNamedUser];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (!self.isDataCollectionEnabled) {
        UA_LWARN(@"Unable to remove tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

    [self.tagGroupsRegistrar removeTags:tags group:tagGroupID type:UATagGroupsTypeNamedUser];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (!self.isDataCollectionEnabled) {
        UA_LWARN(@"Unable to set tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

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

- (void)onDataCollectionEnabledChanged {
    if (!self.isDataCollectionEnabled) {
        self.identifier = nil;
        [self forceUpdate];
    }
}

@end
