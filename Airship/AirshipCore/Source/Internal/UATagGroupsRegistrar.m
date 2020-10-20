/* Copyright Airship and Contributors */

#import "UATagGroupsRegistrar+Internal.h"

#import "UATagGroupsMutation+Internal.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagUtils+Internal.h"
#import "UAAsyncOperation.h"
#import "UAPendingTagGroupStore+Internal.h"

@interface UATagGroupsRegistrar()

/**
 * The pending tag group store.
 */
@property (nonatomic, strong) UAPendingTagGroupStore *pendingTagGroupStore;

/**
 * The tag groups API client.
 */
@property (nonatomic, strong) UATagGroupsAPIClient *tagGroupsAPIClient;

/**
 * The application.
 */
@property (nonatomic, strong) UIApplication *application;

/**
 * The current identifier associated with this registrar.
 */
@property (atomic, copy) NSString *identifier;

/**
 * Whether the client is currently updating.
 */
@property (atomic, assign) BOOL updating;

@end

@implementation UATagGroupsRegistrar

@synthesize enabled = _enabled;

- (instancetype)initWithPendingTagGroupStore:(UAPendingTagGroupStore *)pendingTagGroupStore
                                   apiClient:(UATagGroupsAPIClient *)apiClient
                                 application:application {
    
    self = [super init];

    if (self) {
        self.enabled = YES;
        self.application = application;
        self.pendingTagGroupStore = pendingTagGroupStore;
        self.tagGroupsAPIClient = apiClient;
    }

    return self;
}

+ (instancetype)tagGroupsRegistrarWithPendingTagGroupStore:(UAPendingTagGroupStore *)pendingTagGroupStore
                                                 apiClient:(UATagGroupsAPIClient *)client
                                               application:(UIApplication *)application {

    return [[self alloc] initWithPendingTagGroupStore:(UAPendingTagGroupStore *)pendingTagGroupStore
                                            apiClient:client
                                          application:application];
}

+ (instancetype)channelTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {

    UAPendingTagGroupStore *pendingTagGroupStore = [UAPendingTagGroupStore channelHistoryWithDataStore:dataStore];
    UATagGroupsAPIClient *client =  [UATagGroupsAPIClient channelClientWithConfig:config];

    return [[self alloc] initWithPendingTagGroupStore:pendingTagGroupStore
                                            apiClient:client
                                          application:[UIApplication sharedApplication]];
}

+ (instancetype)namedUserTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {

    UAPendingTagGroupStore *pendingTagGroupStore = [UAPendingTagGroupStore namedUserHistoryWithDataStore:dataStore];
    UATagGroupsAPIClient *client =  [UATagGroupsAPIClient namedUserClientWithConfig:config];

    return [[self alloc] initWithPendingTagGroupStore:pendingTagGroupStore
                                            apiClient:client
                                          application:[UIApplication sharedApplication]];
}

- (void)updateTagGroups {
    @synchronized (self) {
        if (!self.enabled) {
            return;
        }

        if (self.updating) {
            UA_LTRACE(@"Skipping tag groups update, request already in flight");
            return;
        }

        self.updating = YES;
    }

    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [self beginUploading];
    
    if (backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
        UA_LTRACE("Background task unavailable, skipping tag groups update.");
        [self endUploading:backgroundTaskIdentifier];
        return;
    }
    
    [self uploadNextTagGroupMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
}

- (void)popPendingMutation:(UATagGroupsMutation *)mutation identifier:(NSString *)identifier {
    @synchronized (self) {
        // Pop the mutation if it is what we expect and the identifier has not changed
        if ([mutation isEqual:self.pendingTagGroupStore.peekPendingMutation] && [identifier isEqualToString:self.identifier]) {
            [self.pendingTagGroupStore popPendingMutation];
        }
    }
}

- (void)uploadNextTagGroupMutationWithBackgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    UATagGroupsMutation *mutation;
    NSString *identifier;

    @synchronized (self) {
        // collapse mutations
        [self.pendingTagGroupStore collapsePendingMutations];

        // peek at top mutation
        mutation = [self.pendingTagGroupStore peekPendingMutation];

        identifier = self.identifier;
    }

    if (!identifier || !mutation) {
        // no upload work to do - end background task, if necessary, and finish operation
        [self endUploading:backgroundTaskIdentifier];
        return;
    }

    UA_WEAKIFY(self);
    void (^apiCompletionBlock)(NSError *) = ^void(NSError *error) {
        UA_STRONGIFY(self);
        if (!error) {
            // Success - pop uploaded mutation and store the transaction record
            [self popPendingMutation:mutation identifier:identifier];
            [self.delegate uploadedTagGroupsMutation:mutation identifier:identifier];
            [self uploadNextTagGroupMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
        } else if (error.domain == UATagGroupsAPIClientErrorDomain && error.code == UATagGroupsAPIClientErrorUnrecoverableStatus) {
            // Unrecoverable failure - pop mutation and end the task
            [self popPendingMutation:mutation identifier:identifier];
            [self uploadNextTagGroupMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
        } else {
            [self endUploading:backgroundTaskIdentifier];
        }
    };

    [self.tagGroupsAPIClient updateTagGroupsForId:identifier
                                tagGroupsMutation:mutation
                                completionHandler:apiCompletionBlock];
}

- (UIBackgroundTaskIdentifier)beginUploading {
    UA_WEAKIFY(self);
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [self.application beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self);

        UA_LTRACE(@"Tag groups background task expired.");
        [self.tagGroupsAPIClient cancelAllRequests];

        [self endUploading:backgroundTaskIdentifier];
    }];

    return backgroundTaskIdentifier;
}

- (void)endUploading:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    [self endBackgroundTask:backgroundTaskIdentifier];

    @synchronized (self) {
        self.updating = NO;
    }
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [self.application endBackgroundTask:backgroundTaskIdentifier];
    }
}

- (void)mutateTags:(NSArray<NSString *>*)tags
             group:(NSString *)group
             block:(nullable UATagGroupsMutation* (^)(NSArray *, NSString *))block {

    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];
    NSString *normalizedTagGroupID = [UATagUtils normalizeTagGroupID:group];

    if (!normalizedTagGroupID.length) {
        return;
    }

    UATagGroupsMutation *mutation = block(normalizedTags, normalizedTagGroupID);

    if (mutation) {
        [self.pendingTagGroupStore addPendingMutation:mutation];
    }
};

- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self mutateTags:tags group:tagGroupID block:^UATagGroupsMutation *(NSArray *normalizedTags, NSString *normalizedGroup) {
        if (!normalizedTags.count) {
            return nil;
        }

        return [UATagGroupsMutation mutationToAddTags:normalizedTags group:normalizedGroup];
    }];
}

- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self mutateTags:tags group:tagGroupID block:^UATagGroupsMutation *(NSArray *normalizedTags, NSString *normalizedGroup) {
        if (!normalizedTags.count) {
            return nil;
        }

        return [UATagGroupsMutation mutationToRemoveTags:normalizedTags group:normalizedGroup];
    }];}

- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    [self mutateTags:tags group:tagGroupID block:^UATagGroupsMutation *(NSArray *normalizedTags, NSString *normalizedGroup) {
        return [UATagGroupsMutation mutationToSetTags:normalizedTags
                                                group:normalizedGroup];
    }];
}

- (void)clearPendingMutations {
    [self.pendingTagGroupStore clearPendingMutations];
}

- (NSArray<UATagGroupsMutation *> *)pendingMutations {
    return self.pendingTagGroupStore.pendingMutations;
}

- (void)setEnabled:(BOOL)enabled {
    @synchronized (self) {
        _enabled = enabled;
        self.tagGroupsAPIClient.enabled = enabled;
    }
}

- (BOOL)enabled {
    @synchronized (self) {
        return _enabled;
    }
}

- (void)setIdentifier:(NSString *)identifier clearPendingOnChange:(BOOL)clearPendingOnChange {
    @synchronized (self) {
        if (clearPendingOnChange && ![identifier isEqualToString:self.identifier]) {
            [self clearPendingMutations];
        }
        
        self.identifier = identifier;
    }
}

@end
