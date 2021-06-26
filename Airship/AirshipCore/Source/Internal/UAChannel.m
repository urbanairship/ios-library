/* Copyright Airship and Contributors */

#import "UAChannel+Internal.h"
#import "UAChannelRegistrar+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UATagUtils+Internal.h"
#import "UAUtils+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UAKeychainUtils+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

NSString *const UAChannelTagsSettingsKey = @"com.urbanairship.channel.tags";

NSString *const UAChannelDefaultDeviceTagGroup = @"device";

NSNotificationName const UAChannelCreatedEvent = @"com.urbanairship.channel.channel_created";

NSString *const UAChannelUpdatedEvent = @"com.urbanairship.channel.channel_updated";
NSString *const UAChannelRegistrationFailedEvent = @"com.urbanairship.channel.registration_failed";

NSString *const UAChannelUploadedTagGroupMutationNotification = @"com.urbanairship.channel.uploaded_tag_group_mutation";
NSString *const UAChannelUploadedAttributeMutationsNotification = @"com.urbanairship.channel.uploaded_attribute_mutations";

NSString *const UAChannelUploadedAudienceMutationNotificationMutationKey = @"mutation";
NSString *const UAChannelUploadedAudienceMutationNotificationDateKey = @"date";
NSString *const UAChannelUploadedAudienceMutationNotificationIdentifierKey = @"identifier";

NSString *const UAChannelCreatedEventChannelKey = @"com.urbanairship.channel.identifier";
NSString *const UAChannelCreatedEventExistingKey = @"com.urbanairship.channel.existing";

NSString *const UAChannelUpdatedEventChannelKey = @"com.urbanairship.channel.identifier";

static NSString * const UAChannelTagUpdateTaskID = @"UAChannel.tags.update";
static NSString * const UAChannelAttributeUpdateTaskID = @"UAChannel.attributes.update";

@interface UAChannel ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAChannelRegistrar *channelRegistrar;
@property (nonatomic, strong) UATagGroupsRegistrar *tagGroupsRegistrar;
@property (nonatomic, strong) UAAttributeRegistrar *attributeRegistrar;
@property (nonatomic, strong) UALocaleManager *localeManager;

@property (nonatomic, assign) BOOL shouldPerformChannelRegistrationOnForeground;
@property (nonatomic, strong) NSMutableArray<UAChannelRegistrationExtenderBlock> *registrationExtenderBlocks;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UATaskManager *taskManager;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UARuntimeConfig *config;

@end

@implementation UAChannel

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                           config:(UARuntimeConfig *)config
               notificationCenter:(NSNotificationCenter *)notificationCenter
                 channelRegistrar:(UAChannelRegistrar *)channelRegistrar
               tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
               attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                    localeManager:(UALocaleManager *)localeManager
                             date:(UADate *)date
                      taskManager:(UATaskManager *)taskManager
                   privacyManager:(UAPrivacyManager *)privacyManager{
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
        self.channelRegistrar = channelRegistrar;
        self.channelRegistrar.delegate = self;
        self.tagGroupsRegistrar = tagGroupsRegistrar;
        self.attributeRegistrar = attributeRegistrar;
        self.localeManager = localeManager;
        self.privacyManager = privacyManager;
        self.date = date;
        self.taskManager = taskManager;

        self.channelTagRegistrationEnabled = YES;
        self.registrationExtenderBlocks = [NSMutableArray array];

        self.tagGroupsRegistrar.delegate = self;
        self.attributeRegistrar.delegate = self;
        [self.tagGroupsRegistrar setIdentifier:self.identifier clearPendingOnChange:NO];
        [self.attributeRegistrar setIdentifier:self.identifier clearPendingOnChange:NO];

        // Check config to see if user wants to delay channel creation
        // If channel ID exists or channel creation delay is disabled then channelCreationEnabled
        if (self.identifier || !config.isChannelCreationDelayEnabled) {
            self.channelCreationEnabled = YES;
        } else {
            UA_LDEBUG(@"Channel creation disabled.");
            self.channelCreationEnabled = NO;
        }

        // Log the channel ID at error level, but without logging
        // it as an error.
        if (self.identifier && uaLogLevel >= UALogLevelError) {
            NSLog(@"Channel ID: %@", self.identifier);
        }

        UA_WEAKIFY(self)
        [self.taskManager registerForTaskWithIDs:@[UAChannelTagUpdateTaskID, UAChannelAttributeUpdateTaskID]
                                      dispatcher:UADispatcher.serial
                                   launchHandler:^(id<UATask> task) {
            if (!self.componentEnabled) {
                UA_LWARN(@"Channel component is disabled");
                [task taskCompleted];
                return;
            }

            UA_STRONGIFY(self)
            if ([task.taskID isEqualToString:UAChannelTagUpdateTaskID]) {
                [self handleTagUpdateTask:task];
            } else if ([task.taskID isEqualToString:UAChannelAttributeUpdateTaskID]) {
                 [self handleAttributeUpdateTask:task];
            } else {
                UA_LERR(@"Invalid task: %@", task.taskID);
                [task taskCompleted];
            }
        }];

        [self observeNotificationCenterEvents];

        [self updateRegistration];
    }

    return self;
}

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                       localeManager:(UALocaleManager *)localeManager
                      privacyManager:(UAPrivacyManager *)privacyManager{

    UATagGroupsRegistrar *tagGroupsRegistrar = [UATagGroupsRegistrar channelTagGroupsRegistrarWithConfig:config dataStore:dataStore];
    return [[self alloc] initWithDataStore:dataStore
                                    config:config
                        notificationCenter:[NSNotificationCenter defaultCenter]
                        channelRegistrar:[UAChannelRegistrar channelRegistrarWithConfig:config
                                                                              dataStore:dataStore]
                        tagGroupsRegistrar:tagGroupsRegistrar
                        attributeRegistrar:[UAAttributeRegistrar channelRegistrarWithConfig:config
                                                                                  dataStore:dataStore]
                             localeManager:localeManager
                                      date:[[UADate alloc] init]
                               taskManager:[UATaskManager shared]
                            privacyManager:privacyManager];
}

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                    channelRegistrar:(UAChannelRegistrar *)channelRegistrar
                  tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
                  attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                       localeManager:(UALocaleManager *)localeManager
                                date:(UADate *)date
                         taskManager:(UATaskManager *)taskManager
                      privacyManager:(UAPrivacyManager *)privacyManager {
    return [[self alloc] initWithDataStore:dataStore
                                    config:config
                        notificationCenter:notificationCenter
                          channelRegistrar:channelRegistrar
                        tagGroupsRegistrar:tagGroupsRegistrar
                        attributeRegistrar:attributeRegistrar
                             localeManager:localeManager
                                      date:date
                               taskManager:taskManager
                            privacyManager:privacyManager];
}

- (void)observeNotificationCenterEvents {
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationBackgroundRefreshStatusChanged)
                                    name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidTransitionToForeground)
                                    name:UAAppStateTracker.didTransitionToForeground
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(localeUpdated)
                                    name:UALocaleManager.localeUpdatedEvent
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(remoteConfigUpdated)
                                    name:UARemoteConfigURLManagerConfigUpdated
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(onEnabledFeaturesChanged)
                                    name:UAPrivacyManager.changeEvent
                                  object:nil];
}

- (NSString *)identifier {
    return self.channelRegistrar.channelID;
}

#pragma mark -
#pragma mark Application State Observation

- (void)applicationDidTransitionToForeground {
    if ([self.privacyManager isAnyFeatureEnabled]) {
        UA_LTRACE(@"Application did become active. Updating registration.");
        [self updateRegistration];
    }
}

- (void)applicationBackgroundRefreshStatusChanged {
    if ([self.privacyManager isAnyFeatureEnabled]) {
        UA_LTRACE(@"Background refresh status changed.");
        [self updateRegistration];
    }
}

#pragma mark -
#pragma mark Channel Tags

- (NSArray *)tags {
    NSArray *currentTags = [self.dataStore objectForKey:UAChannelTagsSettingsKey];
    if (!currentTags) {
        currentTags = [NSArray array];
    }
    return currentTags;
}

- (void)setTags:(NSArray *)tags {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to modify channel tags %@ when data collection is disabled.", [tags description]);
        return;
    }

    [self.dataStore setObject:[UATagUtils normalizeTags:tags] forKey:UAChannelTagsSettingsKey];
}

- (void)addTag:(NSString *)tag {
    [self addTags:[NSArray arrayWithObject:tag]];
}

- (void)addTags:(NSArray *)tags {
    NSMutableSet *updatedTags = [NSMutableSet setWithArray:self.tags];
    [updatedTags addObjectsFromArray:tags];
    [self setTags:[updatedTags allObjects]];
}

- (void)removeTag:(NSString *)tag {
    [self removeTags:[NSArray arrayWithObject:tag]];
}

- (void)removeTags:(NSArray *)tags {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to modify channel tags %@ when data collection is disabled.", [tags description]);
        return;
    }

    NSMutableArray *mutableTags = [NSMutableArray arrayWithArray:self.tags];
    [mutableTags removeObjectsInArray:tags];
    [self.dataStore setObject:mutableTags forKey:UAChannelTagsSettingsKey];
}

#pragma mark -
#pragma mark Tag Groups

- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to add tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

    if ([UAChannelDefaultDeviceTagGroup isEqualToString:tagGroupID] && self.channelTagRegistrationEnabled) {
        UA_LERR(@"Unable to add tags %@ for device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar addTags:tags group:tagGroupID];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to remove tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

    if ([UAChannelDefaultDeviceTagGroup isEqualToString:tagGroupID] && self.channelTagRegistrationEnabled) {
        UA_LERR(@"Unable to remove tags %@ for device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar removeTags:tags group:tagGroupID];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to set tags %@ for group %@ when data collection is disabled.", [tags description], tagGroupID);
        return;
    }

    if ([UAChannelDefaultDeviceTagGroup isEqualToString:tagGroupID] && self.channelTagRegistrationEnabled) {
        UA_LERR(@"Unable to set tags %@ for device tag group when channelTagRegistrationEnabled is true.", [tags description]);
        return;
    }

    [self.tagGroupsRegistrar setTags:tags group:tagGroupID];
}

#pragma mark -
#pragma mark Channel Attributes

- (void)applyAttributeMutations:(UAAttributeMutations *)mutations {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UA_LWARN(@"Unable to apply attributes %@ when data collection is disabled.", mutations);
        return;
    }

    UAAttributePendingMutations *pendingMutations = [UAAttributePendingMutations pendingMutationsWithMutations:mutations date:self.date];

    // Save pending mutations for upload
    [self.attributeRegistrar savePendingMutations:pendingMutations];

    if (!self.identifier) {
          UA_LTRACE(@"Attribute mutations require a valid channel, mutations have been saved for future update.");
          return;
    }

    [self enqueueUpdateAttributesTask];
}

#pragma mark -
#pragma mark Registration

- (void)enableChannelCreation {
    if (!self.channelCreationEnabled) {
        self.channelCreationEnabled = YES;
        [self updateRegistration];
    }
}

- (void)updateRegistrationForcefully:(BOOL)forcefully {
    if (!self.componentEnabled) {
        return;
    }

    // Only cancel in flight requests if the channel is already created
    if (!self.channelCreationEnabled) {
        UA_LDEBUG(@"Channel creation is currently disabled.");
        return;
    }

    if (self.identifier == nil && ![self.privacyManager isAnyFeatureEnabled]) {
        UA_LTRACE(@"Skipping channel create. All features are disabled.");
        return;
    }

    [self.channelRegistrar registerForcefully:forcefully];
}

- (void)updateRegistration {
    [self enqueueUpdateAttributesTask];
    [self enqueueUpdateTagGroupsTask];
    [self updateRegistrationForcefully:NO];
}

- (NSArray<UATagGroupsMutation *> *)pendingTagGroups {
    return self.tagGroupsRegistrar.pendingMutations;
}

- (UAAttributePendingMutations *)pendingAttributes {
    return self.attributeRegistrar.pendingMutations;
}

#pragma mark -
#pragma mark Task Manager

- (void)enqueueUpdateTagGroupsTask {
    if (self.identifier && self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                    requiresNetwork:YES
                                                                                             extras:nil];
        [self.taskManager enqueueRequestWithID:UAChannelTagUpdateTaskID
                                       options:requestOptions];
    }
}

- (void)enqueueUpdateAttributesTask {
    if (self.identifier && self.componentEnabled && [self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        UATaskRequestOptions *requestOptions = [[UATaskRequestOptions alloc] initWithConflictPolicy:UATaskConflictPolicyAppend
                                                                                    requiresNetwork:YES
                                                                                             extras:nil];
        [self.taskManager enqueueRequestWithID:UAChannelAttributeUpdateTaskID
                                       options:requestOptions];
    }
}

- (void)handleTagUpdateTask:(id<UATask>)task {
    if (!self.identifier || !self.componentEnabled || ![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        [task taskCompleted];
        return;
    }

    UASemaphore *semaphore = [[UASemaphore alloc] init];

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
    if (!self.identifier || !self.componentEnabled || ![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        [task taskCompleted];
        return;
    }

    UASemaphore *semaphore = [[UASemaphore alloc] init];

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

#pragma mark -
#pragma mark Channel Registrar Delegate

- (void)createChannelPayload:(void (^)(UAChannelRegistrationPayload *))completionHandler {
    UAChannelRegistrationPayload *payload = [[UAChannelRegistrationPayload alloc] init];

    if (self.channelTagRegistrationEnabled) {
        payload.tags = self.tags;
        payload.setTags = YES;
    } else {
        payload.setTags = NO;
    }

    if ([self.privacyManager isEnabled:UAFeaturesAnalytics]) {
        payload.deviceModel = [UAUtils deviceModelName];
        payload.carrier = [UAUtils carrierName];
        payload.appVersion = [UAUtils bundleShortVersionString];
        payload.deviceOS = [UIDevice currentDevice].systemVersion;
    }

    if ([self.privacyManager isAnyFeatureEnabled]) {
        NSLocale *currentLocale = [self.localeManager currentLocale];
        payload.language = [currentLocale objectForKey:NSLocaleLanguageCode];
        payload.country = [currentLocale objectForKey: NSLocaleCountryCode];
        payload.timeZone = [NSTimeZone defaultTimeZone].name;
        payload.SDKVersion = [UAirshipVersion get];

        id extendersCopy = [self.registrationExtenderBlocks mutableCopy];
        [UAChannel extendPayload:payload extenders:extendersCopy completionHandler:^(UAChannelRegistrationPayload *payload) {
            completionHandler(payload);
        }];
    } else {
        completionHandler(payload);
    }
}

- (void)registrationSucceeded {
    UA_LINFO(@"Channel registration updated successfully.");

    NSString *channelID = self.identifier;

    if (!channelID) {
        UA_LWARN(@"Channel ID is nil after successful registration.");
        return;
    }

    [UADispatcher.main dispatchAsyncIfNecessary:^{
        [self.notificationCenter postNotificationName:UAChannelUpdatedEvent
                                               object:self
                                             userInfo:@{UAChannelUpdatedEventChannelKey: channelID}];
    }];
}

- (void)registrationFailed {
    UA_LINFO(@"Channel registration failed.");

    [UADispatcher.main dispatchAsyncIfNecessary:^{
        [self.notificationCenter postNotificationName:UAChannelRegistrationFailedEvent
                                               object:self
                                             userInfo:nil];
    }];
}

- (void)channelCreated:(NSString *)channelID
              existing:(BOOL)existing {

    if (channelID) {
        if (uaLogLevel >= UALogLevelError) {
            NSLog(@"Created channel with ID: %@", channelID);
        }

        [self.tagGroupsRegistrar setIdentifier:channelID clearPendingOnChange:NO];
        [self.attributeRegistrar setIdentifier:channelID clearPendingOnChange:NO];

        [UADispatcher.main dispatchAsyncIfNecessary:^{
            [self.notificationCenter postNotificationName:UAChannelCreatedEvent
                                                   object:self
                                                 userInfo:@{UAChannelCreatedEventChannelKey: channelID,
                                                            UAChannelCreatedEventExistingKey: @(existing)}];
        }];
    } else {
        UA_LERR(@"Channel creation failed. Missing channelID: %@", channelID);
    }
}

- (void)uploadedTagGroupsMutation:(UATagGroupsMutation *)mutation identifier:(NSString *)identifier {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedTagGroupMutationNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutation,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:[NSDate date],
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:identifier }];
}

- (void)uploadedAttributeMutations:(UAAttributePendingMutations *)mutations identifier:(NSString *)identifier {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAChannelUploadedAttributeMutationsNotification
                                                        object:nil
                                                      userInfo:@{UAChannelUploadedAudienceMutationNotificationMutationKey:mutations,
                                                                 UAChannelUploadedAudienceMutationNotificationDateKey:[NSDate date],
                                                                 UAChannelUploadedAudienceMutationNotificationIdentifierKey:identifier }];
}

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        [self updateRegistration];
    }
}

- (void)onEnabledFeaturesChanged {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        // Clear channel tags and pending mutations
        [self.dataStore removeObjectForKey:UAChannelTagsSettingsKey];
        [self.attributeRegistrar clearPendingMutations];
        [self.tagGroupsRegistrar clearPendingMutations];
    }

    [self updateRegistrationForcefully:NO];
}

- (void)addChannelExtenderBlock:(UAChannelRegistrationExtenderBlock)extender {
    [self.registrationExtenderBlocks addObject:extender];
}

/**
 * Helper method to extend the CRA payload sequentially with extender blocks.
 * @param payload The CRA payload.
 * @param remainingExtenderBlocks The remaining extender blocks.
 * @param completionHandler The completion handler.
 */
+ (void)extendPayload:(UAChannelRegistrationPayload *)payload
            extenders:(NSMutableArray<UAChannelRegistrationExtenderBlock> *)remainingExtenderBlocks
    completionHandler:(void (^)(UAChannelRegistrationPayload *))completionHandler {

    if (!remainingExtenderBlocks.count) {
        completionHandler(payload);
        return;
    }

    UAChannelRegistrationExtenderBlock block = remainingExtenderBlocks.firstObject;
    [remainingExtenderBlocks removeObjectAtIndex:0];

    [UADispatcher.main dispatchAsyncIfNecessary:^{
        block(payload, ^(UAChannelRegistrationPayload *payload) {
                [self extendPayload:payload extenders:remainingExtenderBlocks completionHandler:completionHandler];
        });
    }];
}

- (void)remoteConfigUpdated {
    if (self.isChannelCreationEnabled && self.identifier) {
        [self.channelRegistrar performFullRegistration];
    }
}

#pragma mark -
#pragma mark UAPushableComponent

-(void)receivedRemoteNotification:(UANotificationContent *)notification
                completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    BOOL isInBackground = [UIApplication sharedApplication].applicationState == UIApplicationStateBackground;
    if (isInBackground && !self.identifier) {
        // Update registration if the channel identifier does not exist
        [self updateRegistrationForcefully:NO];
    }
    completionHandler(UIBackgroundFetchResultNoData);
}

#pragma mark -
#pragma mark Locale update

- (void)localeUpdated {
    [self updateRegistrationForcefully:NO];
}


@end
