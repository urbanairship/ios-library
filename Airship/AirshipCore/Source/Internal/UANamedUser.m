/* Copyright Airship and Contributors */

#import "UANamedUser+Internal.h"
#import "UAChannel.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagUtils+Internal.h"
#import "UARuntimeConfig.h"
#import "UAAttributePendingMutations.h"
#import "UAAttributeRegistrar+Internal.h"
#import "UADate.h"
#import "UATaskManager.h"
#import "UASemaphore.h"
#import "UARemoteConfigURLManager.h"
#import "UAGlobal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

#define kUAMaxNamedUserIDLength 128

NSString *const UANamedUserIDKey = @"UANamedUserID";
NSString *const UANamedUserChangeTokenKey = @"UANamedUserChangeToken";
NSString *const UANamedUserLastUpdatedTokenKey = @"UANamedUserLastUpdatedToken";
NSString *const UANamedUserLastChannelIDKey = @"UANamedUserLastChannelID";

NSString *const UANamedUserUploadedTagGroupMutationNotification = @"com.urbanairship.named_user.uploaded_tag_group_mutation";
NSString *const UANamedUserUploadedAttributeMutationsNotification = @"com.urbanairship.named_user.uploaded_attribute_mutations";

NSString *const UANamedUserUploadedAudienceMutationNotificationMutationKey = @"mutation";
NSString *const UANamedUserUploadedAudienceMutationNotificationDateKey = @"date";
NSString *const UANamedUserUploadedAudienceMutationNotificationIdentifierKey = @"identifier";

NSString *const UANamedUserIdentifierChangedNotification = @"com.urbanairship.named_user_identifier_changed";
NSString *const UANamedUserIdentifierChangedNotificationIdentifierKey = @"identifier";

static NSString * const UANamedUserUpdateTaskID = @"UANamedUser.update";
static NSString * const UANamedUserTagUpdateTaskID = @"UANamedUser.tags.update";
static NSString * const UANamedUserAttributeUpdateTaskID = @"UANamedUser.attributes.update";

@interface UANamedUser()

@property (nonatomic, copy, nullable) NSString *changeToken;
@property (nonatomic, copy, nullable) NSString *lastUpdatedToken;
@property (nonatomic, strong) UANamedUserAPIClient *namedUserAPIClient;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannel<UAExtendableChannelRegistration> *channel;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UATagGroupsRegistrar *tagGroupsRegistrar;
@property (nonatomic, copy) NSString *lastChannelID;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UAAttributeRegistrar *attributeRegistrar;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UATaskManager *taskManager;
@end

@implementation UANamedUser

- (instancetype)initWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                         config:(UARuntimeConfig *)config
             notificationCenter:(NSNotificationCenter *)notificationCenter
                      dataStore:(UAPreferenceDataStore *)dataStore
             tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
             attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                           date:(UADate *)date
                    taskManager:(UATaskManager *)taskManager
                namedUserClient:(UANamedUserAPIClient *)namedUserClient
                 privacyManager:(UAPrivacyManager *)privacyManager {

    self = [super initWithDataStore:dataStore];
    if (self) {
        self.channel = channel;
        self.config = config;
        self.notificationCenter = notificationCenter;
        self.dataStore = dataStore;
        self.privacyManager = privacyManager;
        self.namedUserAPIClient = namedUserClient;
        self.tagGroupsRegistrar = tagGroupsRegistrar;
        self.attributeRegistrar = attributeRegistrar;
        self.date = date;
        self.taskManager = taskManager;

        self.attributeRegistrar.delegate = self;
        self.tagGroupsRegistrar.delegate = self;
        [self.tagGroupsRegistrar setIdentifier:self.identifier clearPendingOnChange:NO];
        [self.attributeRegistrar setIdentifier:self.identifier clearPendingOnChange:NO];

        [self.notificationCenter addObserver:self
                                    selector:@selector(channelCreated:)
                                        name:UAChannelCreatedEvent
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(remoteConfigUpdated)
                                        name:UARemoteConfigURLManagerConfigUpdated
                                      object:nil];

        [self.notificationCenter addObserver:self
                                    selector:@selector(onEnabledFeaturesChanged)
                                        name:UAPrivacyManager.changeEvent
                                      object:nil];
        UA_WEAKIFY(self)
        [self.channel addChannelExtenderBlock:^(UAChannelRegistrationPayload *payload, UAChannelRegistrationExtenderCompletionHandler completionHandler) {
            UA_STRONGIFY(self)
            [self extendChannelRegistrationPayload:payload completionHandler:completionHandler];
        }];

        [self.taskManager registerForTaskWithIDs:@[UANamedUserUpdateTaskID, UANamedUserTagUpdateTaskID, UANamedUserAttributeUpdateTaskID]
                                      dispatcher:[UADispatcher serialDispatcher]
                                   launchHandler:^(id<UATask> task) {

            if (!self.componentEnabled) {
                UA_LERR(@"Component disabled, unable to handle task");
                [task taskCompleted];
                return;
            }

            UA_STRONGIFY(self)
            if ([task.taskID isEqualToString:UANamedUserUpdateTaskID]) {
                [self handleUpdateTask:task];
            } else if ([task.taskID isEqualToString:UANamedUserTagUpdateTaskID]) {
                [self handleTagUpdateTask:task];
            } else if ([task.taskID isEqualToString:UANamedUserAttributeUpdateTaskID]) {
                [self handleAttributeUpdateTask:task];
            } else {
                UA_LERR(@"Invalid task: %@", task.taskID);
                [task taskCompleted];
            }
        }];

        // Update the named user if necessary.
        [self update];
    }

    return self;
}

+ (instancetype)namedUserWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                              config:(UARuntimeConfig *)config
                           dataStore:(UAPreferenceDataStore *)dataStore
                      privacyManager:(UAPrivacyManager *)privacyManager {

    UATagGroupsRegistrar *tagGroupsRegistrar = [UATagGroupsRegistrar namedUserTagGroupsRegistrarWithConfig:config dataStore:dataStore];
    UAAttributeRegistrar *atttributeRegistrar = [UAAttributeRegistrar namedUserRegistrarWithConfig:config
                                                                                         dataStore:dataStore];

    return [[UANamedUser alloc] initWithChannel:channel
                                         config:config
                             notificationCenter:[NSNotificationCenter defaultCenter]
                                      dataStore:dataStore
                             tagGroupsRegistrar:tagGroupsRegistrar
                             attributeRegistrar:atttributeRegistrar
                                           date:[[UADate alloc] init]
                                    taskManager:[UATaskManager shared]
                                namedUserClient:[[UANamedUserAPIClient alloc] initWithConfig:config]
                                 privacyManager:privacyManager];
}

+ (instancetype)namedUserWithChannel:(UAChannel<UAExtendableChannelRegistration> *)channel
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                           dataStore:(UAPreferenceDataStore *)dataStore
                  tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
                  attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                                date:(UADate *)date
                         taskManager:(UATaskManager *)taskManager
                     namedUserClient:(UANamedUserAPIClient *)namedUserClient
                      privacyManager:(UAPrivacyManager *)privacyManager {

    return [[UANamedUser alloc] initWithChannel:channel
                                         config:config
                             notificationCenter:notificationCenter
                                      dataStore:dataStore
                             tagGroupsRegistrar:tagGroupsRegistrar
                             attributeRegistrar:attributeRegistrar
                                           date:date
                                    taskManager:taskManager
                                namedUserClient:namedUserClient
                                 privacyManager:privacyManager];
}

- (void)update {
    [self enqueueUpdateNamedUserTask];
    [self enqueueUpdateTagGroupsTask];
    [self enqueueUpdateAttributesTask];
}

- (void)enqueueUpdateNamedUserTask {
    UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    [self.taskManager enqueueRequestWithID:UANamedUserUpdateTaskID
                                   options:requestOptions];
}

- (void)enqueueUpdateTagGroupsTask {
    if (self.identifier && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
        [self.taskManager enqueueRequestWithID:UANamedUserTagUpdateTaskID
                                       options:requestOptions];
    }
}

- (void)enqueueUpdateAttributesTask {
    if (self.identifier && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UATaskRequestOptions *requestOptions = [UATaskRequestOptions optionsWithConflictPolicy:UATaskConflictPolicyAppend requiresNetwork:YES extras:nil];
        [self.taskManager enqueueRequestWithID:UANamedUserAttributeUpdateTaskID
                                       options:requestOptions];
    }
}

- (void)handleUpdateTask:(id<UATask>)task {
    if (!self.changeToken && !self.lastUpdatedToken) {
        // Skip since no one has set the named user ID. Usually from a new or re-install.
        UA_LDEBUG(@"New or re-install, skipping named user update.");
        [task taskCompleted];
        return;
    }

    if ([self.lastChannelID isEqualToString:self.channel.identifier] && [self.changeToken isEqualToString:self.lastUpdatedToken]) {
        // Skip since no change has occurred (token remains the same).
        UA_LDEBUG(@"Named user already updated. Skipping.");
        [task taskCompleted];
        return;
    }

    if (!self.channel.identifier) {
        // Skip since we don't have a channel ID.
        UA_LDEBUG(@"The channel ID does not exist. Will retry when channel ID is available.");
        [task taskCompleted];
        return;
    }

    UADisposable *request;
    UASemaphore *semaphore = [UASemaphore semaphore];

    // Treat a nil or empty string as a command to disassociate the named user
    if (self.identifier && [self.identifier length] != 0) {
        // When identifier is non-nil, associate the current named user ID.
        request = [self associateNamedUserWithCompletionHandler:^(BOOL completed) {
            if (completed) {
                [task taskCompleted];
            } else {
                [task taskFailed];
            }
            [semaphore signal];
        }];
    } else {
        // When identifier is nil, disassociate the current named user ID.
        request = [self disassociateNamedUserWithCompletionHandler:^(BOOL completed) {
            if (completed) {
                [task taskCompleted];
            } else {
                [task taskFailed];
            }
            [semaphore signal];
        }];
    }

    task.expirationHandler = ^{
        [request dispose];
    };

    [semaphore wait];
}

- (void)handleTagUpdateTask:(id<UATask>)task {
    if (!(self.identifier && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes])) {
        [task taskCompleted];
        return;
    }

    UASemaphore *semaphore = [UASemaphore semaphore];

    UADisposable *request = [self.tagGroupsRegistrar updateTagGroupsWithCompletionHandler:^(UATagGroupsUploadResult result) {
        switch (result) {
            case UATagGroupsUploadResultFinished:
                [task taskCompleted];
                [self enqueueUpdateTagGroupsTask];
                break;
            case UATagGroupsUploadResultUpToDate:
                [task taskCompleted];
                break;
            case UATagGroupsUploadResultFailed:
                [task taskFailed];
                break;
        }
        [semaphore signal];
    }];


    task.expirationHandler = ^{
        [request dispose];
    };

    [semaphore wait];
}

- (void)handleAttributeUpdateTask:(id<UATask>)task {
    if (!(self.identifier && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes])) {
        [task taskCompleted];
        return;
    }

    UASemaphore *semaphore = [UASemaphore semaphore];

    UADisposable *request = [self.attributeRegistrar updateAttributesWithCompletionHandler:^(UAAttributeUploadResult result) {
        switch (result) {
            case UAAttributeUploadResultFinished:
                [task taskCompleted];
                [self enqueueUpdateAttributesTask];
                break;
            case UAAttributeUploadResultUpToDate:
                [task taskCompleted];
                break;
            case UAAttributeUploadResultFailed:
                [task taskFailed];
                break;
        }
        [semaphore signal];
    }];

    task.expirationHandler = ^{
        [request dispose];
    };

    [semaphore wait];
}

- (NSString *)identifier {
    return [self.dataStore objectForKey:UANamedUserIDKey];
}

- (void)setIdentifier:(NSString *)identifier {
    if (identifier && ![self.privacyManager isEnabled:UAFeaturesContacts]) {
        UA_LWARN(@"Ignoring named user ID request, contacts are disabled.");
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
        [self enqueueUpdateNamedUserTask];

        [self.tagGroupsRegistrar setIdentifier:trimmedID clearPendingOnChange:YES];
        [self.attributeRegistrar setIdentifier:trimmedID clearPendingOnChange:YES];

        // Identifier is non-null. Update CRA.
        if (self.identifier) {
            [self.channel updateRegistration];
        }

        // Notify observers that the identifier has changed.
        NSDictionary *userInfo = self.identifier ? @{UANamedUserIdentifierChangedNotificationIdentifierKey : self.identifier} : @{};

        [self.notificationCenter postNotificationName:UANamedUserIdentifierChangedNotification
                                               object:nil
                                             userInfo:userInfo];
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

- (UADisposable *)associateNamedUserWithCompletionHandler:(void(^)(BOOL completed))completionHandler {
    NSString *token = self.changeToken;
    NSString *channelID = self.channel.identifier;

    return [self.namedUserAPIClient associate:self.identifier
                                    channelID:channelID
                            completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LDEBUG(@"Failed to associate channel to named user.");
            completionHandler(NO);
        } else if (response.isSuccess) {
            UA_LDEBUG(@"Named user associated to channel successfully.");
            self.lastUpdatedToken = token;
            self.lastChannelID = channelID;
            completionHandler(YES);
        } else {
            UA_LDEBUG(@"Failed to associate channel to named user.");
            if (response.isServerError || response.status == 429) {
                completionHandler(NO);
            } else {
                completionHandler(YES);
            }
        }
    }];
}

- (UADisposable *)disassociateNamedUserWithCompletionHandler:(void(^)(BOOL completed))completionHandler {
    NSString *token = self.changeToken;
    NSString *channelID = self.channel.identifier;

    return [self.namedUserAPIClient disassociate:channelID
                               completionHandler:^(UAHTTPResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            UA_LDEBUG(@"Failed to disassociate channel from named user.");
            completionHandler(NO);
        } else if (response.isSuccess) {
            UA_LDEBUG(@"Named user disassociated from channel successfully.");
            self.lastUpdatedToken = token;
            self.lastChannelID = channelID;
            completionHandler(YES);
        } else {
            UA_LDEBUG(@"Failed to disassociate channel from named user.");
            if (response.isServerError || response.status == 429) {
                completionHandler(NO);
            } else {
                completionHandler(YES);
            }
        }
    }];
}

- (void)forceUpdate {
    UA_LTRACE(@"NamedUser - force named user update.");
    self.changeToken = [NSUUID UUID].UUIDString;
    [self update];
}

- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to add tags %@ for group %@ when tags and attributes are disabled.", [tags description], tagGroupID);
        return;
    }

    if (!self.identifier) {
        UA_LERR(@"Can't update tags without first setting a named user identifier.");
        return;
    }

    [self.tagGroupsRegistrar addTags:tags group:tagGroupID];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to remove tags %@ for group %@ when tags and attributes are disabled.", [tags description], tagGroupID);
        return;
    }

    if (!self.identifier) {
        UA_LERR(@"Can't update tags without first setting a named user identifier.");
        return;
    }

    [self.tagGroupsRegistrar removeTags:tags group:tagGroupID];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to set tags %@ for group %@ when tags and attributes are disabled.", [tags description], tagGroupID);
        return;
    }

    if (!self.identifier) {
        UA_LERR(@"Can't update tags without first setting a named user identifier.");
        return;
    }

    [self.tagGroupsRegistrar setTags:tags group:tagGroupID];
}

- (void)updateTags {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Can't update contacts are disabled");
        return;
    }

    if (!self.identifier) {
        UA_LERR(@"Can't update tags without first setting a named user identifier.");
        return;
    }

    [self enqueueUpdateTagGroupsTask];
}

- (void)extendChannelRegistrationPayload:(UAChannelRegistrationPayload *)payload
                       completionHandler:(UAChannelRegistrationExtenderCompletionHandler)completionHandler {
    payload.namedUserId = self.identifier;
    completionHandler(payload);
}

- (void)channelCreated:(NSNotification *)notification {
    BOOL existing = [notification.userInfo[UAChannelCreatedEventExistingKey] boolValue];

    // If this channel previously existed, a named user may be associated to it.
    if (existing && self.config.clearNamedUserOnAppRestore) {
        if (!self.identifier) {
            [self forceUpdate];
        }
    } else if (self.identifier) {
        // Once we get a channel, update the named user if necessary.
        [self forceUpdate];
    }
}

- (void)uploadedTagGroupsMutation:(UATagGroupsMutation *)mutation identifier:(NSString *)identifier {
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutation,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:[NSDate date],
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:identifier }];
}

- (void)uploadedAttributeMutations:(UAAttributePendingMutations *)mutations identifier:(NSString *)identifier {
    [[NSNotificationCenter defaultCenter] postNotificationName:UANamedUserUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UANamedUserUploadedAudienceMutationNotificationMutationKey:mutations,
                                                                 UANamedUserUploadedAudienceMutationNotificationDateKey:[NSDate date],
                                                                 UANamedUserUploadedAudienceMutationNotificationIdentifierKey:identifier }];
}


- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        [self update];
    }
}

- (void)onEnabledFeaturesChanged {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        // Clear the pending mutations
        [self.attributeRegistrar clearPendingMutations];
        [self.tagGroupsRegistrar clearPendingMutations];
    }

    if (![self.privacyManager isEnabled:UAFeaturesContacts] && self.identifier != nil) {
        // Clear the identifier
        self.identifier = nil;
        [self update];
    }
}

- (NSArray<UATagGroupsMutation *> *)pendingTagGroups {
    return self.tagGroupsRegistrar.pendingMutations;
}

- (UAAttributePendingMutations *)pendingAttributes {
    return self.attributeRegistrar.pendingMutations;
}

#pragma mark -
#pragma mark Named User Attributes

- (void)applyAttributeMutations:(UAAttributeMutations *)mutations {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to apply attributes %@ when tags and attributes are disabled.", mutations);
        return;
    }

    if (!self.identifier) {
        UA_LERR(@"Can't update attributes without first setting a named user identifier.");
        return;
    }

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations date:self.date];
    [self.attributeRegistrar savePendingMutations:pendingMutations];
    [self enqueueUpdateAttributesTask];
}

- (void)remoteConfigUpdated {
    if (self.identifier && self.channel.identifier) {
        [self forceUpdate];
    }
}

@end
