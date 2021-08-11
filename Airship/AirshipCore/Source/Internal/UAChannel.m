/* Copyright Airship and Contributors */

#import "UAChannel+Internal.h"
#import "UAUtils+Internal.h"
#import "UAChannelRegistrationPayload+Internal.h"
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

NSNotificationName const UAChannelAudienceUpdatedEvent = @"UAChannel.audienceUpdated";
NSString *const UAChannelAudienceUpdatedEventTagsKey = @"tags";
NSString *const UAChannelAudienceUpdatedEventAttributesKey = @"attributes";

NSString *const UAChannelCreatedEventChannelKey = @"com.urbanairship.channel.identifier";
NSString *const UAChannelCreatedEventExistingKey = @"com.urbanairship.channel.existing";

NSString *const UAChannelUpdatedEventChannelKey = @"com.urbanairship.channel.identifier";

@interface UAChannel () <UAChannelRegistrarDelegate, UAPushableComponent>
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;
@property (nonatomic, strong) UAChannelRegistrar *channelRegistrar;
@property (nonatomic, strong) UALocaleManager *localeManager;
@property (nonatomic, strong) UAChannelAudienceManager *audienceManager;

@property (nonatomic, assign) BOOL shouldPerformChannelRegistrationOnForeground;
@property (nonatomic, strong) NSMutableArray<UAChannelRegistrationExtenderBlock> *registrationExtenderBlocks;
@property (nonatomic, strong) UADate *date;
@property (nonatomic, strong) UAPrivacyManager *privacyManager;
@property (nonatomic, strong) UARuntimeConfig *config;

@end

@implementation UAChannel

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                           config:(UARuntimeConfig *)config
               notificationCenter:(NSNotificationCenter *)notificationCenter
                 channelRegistrar:(UAChannelRegistrar *)channelRegistrar
                  audienceManager:(UAChannelAudienceManager *)audienceManager
                    localeManager:(UALocaleManager *)localeManager
                             date:(UADate *)date
                   privacyManager:(UAPrivacyManager *)privacyManager {
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.dataStore = dataStore;
        self.notificationCenter = notificationCenter;
        self.channelRegistrar = channelRegistrar;
        self.channelRegistrar.delegate = self;
        self.localeManager = localeManager;
        self.privacyManager = privacyManager;
        self.date = date;
        self.audienceManager = audienceManager;

        self.channelTagRegistrationEnabled = YES;
        self.registrationExtenderBlocks = [NSMutableArray array];
        self.audienceManager.channelID = self.identifier;
        self.audienceManager.enabled = self.componentEnabled;
        
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

        [self observeNotificationCenterEvents];
        [self updateRegistration];
    }

    return self;
}

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                       localeManager:(UALocaleManager *)localeManager
                      privacyManager:(UAPrivacyManager *)privacyManager{
    
    UAChannelAudienceManager *audienceManager = [[UAChannelAudienceManager alloc] initWithDataStore:dataStore config:config privacyManager:privacyManager];
                          
    return [[self alloc] initWithDataStore:dataStore
                                    config:config
                        notificationCenter:[NSNotificationCenter defaultCenter]
                        channelRegistrar:[[UAChannelRegistrar alloc] initWithConfig:config dataStore:dataStore]
                           audienceManager:audienceManager
                             localeManager:localeManager
                                      date:[[UADate alloc] init]
                            privacyManager:privacyManager];
}

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                    channelRegistrar:(UAChannelRegistrar *)channelRegistrar
                     audienceManager:(UAChannelAudienceManager *)audienceManager
                       localeManager:(UALocaleManager *)localeManager
                                date:(UADate *)date
                      privacyManager:(UAPrivacyManager *)privacyManager {
    
    return [[self alloc] initWithDataStore:dataStore
                                    config:config
                        notificationCenter:notificationCenter
                          channelRegistrar:channelRegistrar
                           audienceManager:audienceManager
                             localeManager:localeManager
                                      date:date
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

    [self.dataStore setObject:[UAAudienceUtils normalizeTags:tags] forKey:UAChannelTagsSettingsKey];
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
    UATagGroupsEditor *editor = [self editTagGroups];
    [editor addTags:tags group:tagGroupID];
    [editor apply];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    UATagGroupsEditor *editor = [self editTagGroups];
    [editor removeTags:tags group:tagGroupID];
    [editor apply];
}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    UATagGroupsEditor *editor = [self editTagGroups];
    [editor setTags:tags group:tagGroupID];
    [editor apply];
}

- (UATagGroupsEditor *)editTagGroups {
    return [self.audienceManager editTagGroupsWithAllowDeviceGroup:!self.channelTagRegistrationEnabled];
}


#pragma mark -
#pragma mark Channel Attributes

- (UAAttributesEditor *)editAttributes {
    return [self.audienceManager editAttributes];
}

- (void)applyAttributeMutations:(UAAttributeMutations *)mutations {
    UAAttributesEditor *editor = [self editAttributes];
    [mutations applyMutationsWithEditor:editor];
    [editor apply];
}

#pragma mark -
#pragma mark Channel subscription lists

- (UASubscriptionListEditor *)editSubscriptionLists {
    return [self.audienceManager editSubscriptionLists];
}

- (UADisposable *)fetchSubscriptionListsWithCompletionHandler:(void(^)(NSArray<NSString *> * _Nullable listIDs, NSError * _Nullable error))completionHandler {
    return [self.audienceManager fetchSubscriptionListsWithCompletionHandler:completionHandler];
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
    [self updateRegistrationForcefully:NO];
}

- (NSArray<UATagGroupUpdate *> *)pendingTagGroupUpdates {
    return self.audienceManager.pendingTagGroupUpdates;
}

- (NSArray<UAAttributeUpdate *> *)pendingAttributeUpdates {
    return self.audienceManager.pendingAttributeUpdates;
}

#pragma mark -
#pragma mark Channel Registrar Delegate

- (void)createChannelPayloadWithCompletionHandler:(void (^ _Nonnull)(UAChannelRegistrationPayload * _Nonnull))completionHandler {
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


- (void)channelCreatedWithChannelID:(NSString *)channelID
                           existing:(BOOL)existing {

    if (channelID) {
        if (uaLogLevel >= UALogLevelError) {
            NSLog(@"Created channel with ID: %@", channelID);
        }

        self.audienceManager.channelID = channelID;

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

- (void)onComponentEnableChange {
    if (self.componentEnabled) {
        [self updateRegistration];
    }
    self.audienceManager.enabled = self.componentEnabled;
}

- (void)onEnabledFeaturesChanged {
    if (![self.privacyManager isEnabled:UAFeaturesTagsAndAttributes]) {
        // Clear channel tags and pending mutations
        [self.dataStore removeObjectForKey:UAChannelTagsSettingsKey];
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

#pragma mAark -
#pragma mark UAPushableComponent

-(void)receivedRemoteNotification:(UNNotificationContent *)notification
                completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {
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
