/* Copyright 2018 Urban Airship and Contributors */

#import "UATagGroupsRegistrar+Internal.h"

#import "UATagGroupsAPIClient+Internal.h"
#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"
#import "UATagUtils+Internal.h"
#import "UAAsyncOperation+Internal.h"

// Prefix for channel tag group keys
NSString *const UAPushTagGroupsKeyPrefix = @"UAPush";

// Prefix for named user tag group keys
NSString *const UANamedUserTagGroupsKeyPrefix = @"UANamedUser";

@interface UATagGroupsRegistrar()

/**
 * The tag groups API client.
 */
@property (nonatomic, strong) UATagGroupsAPIClient *tagGroupsAPIClient;

/**
 * Add tag groups data store key.
 */
@property (nonatomic, strong) NSString *addTagGroupsSettingsKey;

/**
 * The queue on which to serialize tag groups operations.
 */
@property (nonatomic,strong) NSOperationQueue *operationQueue;

/**
 * Remove tag groups data store key.
 */
@property (nonatomic, strong) NSString *removeTagGroupsSettingsKey;

/**
 * Tag group mutations data store key.
 */
@property (nonatomic, strong) NSString *tagGroupsMutationsKey;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UATagGroupsRegistrar

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore keyPrefix:(NSString *)keyPrefix apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.dataStore = dataStore;
        
        self.tagGroupsAPIClient = apiClient;
        self.tagGroupsAPIClient.enabled = self.componentEnabled;
        
        self.addTagGroupsSettingsKey = [NSString stringWithFormat:@"%@AddTagGroups",keyPrefix];
        self.removeTagGroupsSettingsKey = [NSString stringWithFormat:@"%@RemoveTagGroups",keyPrefix];
        self.tagGroupsMutationsKey = [NSString stringWithFormat:@"%@TagGroupsMutations",keyPrefix];
        
        self.operationQueue = operationQueue;
        self.operationQueue.maxConcurrentOperationCount = 1;

        [self.dataStore migrateTagGroupSettingsForAddTagsKey:self.addTagGroupsSettingsKey
                                               removeTagsKey:self.removeTagGroupsSettingsKey
                                                      newKey:self.tagGroupsMutationsKey];
    }
    return self;
}

+ (instancetype)channelTagGroupsRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore keyPrefix:UAPushTagGroupsKeyPrefix apiClient:[UATagGroupsAPIClient channelClientWithConfig:config] operationQueue:[[NSOperationQueue alloc] init]];
}

+ (instancetype)channelTagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore keyPrefix:UAPushTagGroupsKeyPrefix apiClient:apiClient operationQueue:operationQueue];
}

+ (instancetype)namedUserTagGroupsRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore keyPrefix:UANamedUserTagGroupsKeyPrefix apiClient:[UATagGroupsAPIClient namedUserClientWithConfig:config] operationQueue:[[NSOperationQueue alloc] init]];
}

+ (instancetype)namedUserTagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore keyPrefix:UANamedUserTagGroupsKeyPrefix apiClient:apiClient operationQueue:operationQueue];
}

- (void)dealloc {
    [self.operationQueue cancelAllOperations];
}

- (void)updateTagGroupsForID:(NSString *)identifier {
    if (!self.componentEnabled) {
        return;
    }
    
    UA_WEAKIFY(self);
    
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self);
        
        UA_LTRACE(@"Tag groups background task expired.");
        [self.tagGroupsAPIClient cancelAllRequests];
        
        [self endBackgroundTask:backgroundTaskIdentifier];
    }];
    
    if (backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
        UA_LTRACE("Background task unavailable, skipping tag groups update.");
        return;
    }
    
    [self uploadNextTagGroupMutationForID:identifier withBackgroundTaskIdentifier:backgroundTaskIdentifier];
}

// this method runs asynchronously on the operation queue
- (void)uploadNextTagGroupMutationForID:(NSString *)identifier withBackgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        // return early if the operation has been cancelled
        if (operation.isCancelled) {
            [self endBackgroundTask:backgroundTaskIdentifier];
            [operation finish];
            return;
        }
        
        if (backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
            UA_LTRACE("Background task no longer available, aborting tag groups update.");
            [operation finish];
            return;
        }
        
        // collapse mutations
        [self.dataStore collapseTagGroupsMutationForKey:self.tagGroupsMutationsKey];
        
        // peek at top mutation
        UATagGroupsMutation *mutation = [self.dataStore peekTagGroupsMutationForKey:self.tagGroupsMutationsKey];
        
        if (!mutation) {
            // no upload work to do - end background task, if necessary, and finish operation
            [self endBackgroundTask:backgroundTaskIdentifier];
            [operation finish];
            return;
        }
        
        UA_WEAKIFY(self);
        void (^apiCompletionBlock)(NSUInteger) = ^void(NSUInteger status) {
            UA_STRONGIFY(self);
            if (status >= 200 && status <= 299) {
                // success - pop uploaded mutation and try to upload next mutation
                [self.dataStore popTagGroupsMutationForKey:self.tagGroupsMutationsKey];
                if (operation.isCancelled) {
                    [self endBackgroundTask:backgroundTaskIdentifier];
                } else {
                    // upload next tag group mutation
                    [self uploadNextTagGroupMutationForID:identifier withBackgroundTaskIdentifier:backgroundTaskIdentifier];
                }
            } else if (status == 400 || status == 403) {
                [self.dataStore popTagGroupsMutationForKey:self.tagGroupsMutationsKey];
                [self endBackgroundTask:backgroundTaskIdentifier];
            }
            [operation finish];
        };
        
        [self.tagGroupsAPIClient updateTagGroupsForId:identifier
                                    tagGroupsMutation:mutation
                                    completionHandler:apiCompletionBlock];
        
    }];
    
    [self.operationQueue addOperation:operation];
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}

// this method may finish asynchronously on the operation queue
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID {
    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];
    NSString *normalizedTagGroupID = [UATagUtils normalizeTagGroupID:tagGroupID];
    if (!normalizedTags.count || !normalizedTagGroupID.length) {
        return;
    }
    
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToAddTags:normalizedTags
                                                                     group:normalizedTagGroupID];
    
    // rest runs on the operation queue
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.dataStore addTagGroupsMutation:mutation forKey:self.tagGroupsMutationsKey];
    }]];
}

// this method may finish asynchronously on the operation queue
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID {
    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];
    NSString *normalizedTagGroupID = [UATagUtils normalizeTagGroupID:tagGroupID];
    
    if (!normalizedTags.count || !normalizedTagGroupID.length) {
        return;
    }
    
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToRemoveTags:normalizedTags
                                                                        group:normalizedTagGroupID];
    
    // rest runs on the operation queue
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.dataStore addTagGroupsMutation:mutation forKey:self.tagGroupsMutationsKey];
    }]];
}

// this method may finish asynchronously on the operation queue
- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID {
    NSArray *normalizedTags = [UATagUtils normalizeTags:tags];
    NSString *normalizedTagGroupID = [UATagUtils normalizeTagGroupID:tagGroupID];
    
    if (!normalizedTagGroupID.length) {
        return;
    }
    
    UATagGroupsMutation *mutation = [UATagGroupsMutation mutationToSetTags:normalizedTags
                                                                     group:normalizedTagGroupID];
    
    // rest runs on the operation queue
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.dataStore addTagGroupsMutation:mutation forKey:self.tagGroupsMutationsKey];
    }]];
}

- (void)clearAllPendingTagUpdates {
    [self.operationQueue cancelAllOperations];
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.dataStore removeObjectForKey:self.tagGroupsMutationsKey];
    }]];
}

- (void)onComponentEnableChange {
    self.tagGroupsAPIClient.enabled = self.componentEnabled;
}


@end
