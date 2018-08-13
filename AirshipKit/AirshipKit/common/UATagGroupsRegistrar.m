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

// Typedef for generating tag group mutation factory blocks
typedef UATagGroupsMutation * (^UATagGroupsMutationFactory)(NSArray *, NSString *);

// Typedef for generating tag group mutator blocks
typedef void (^UATagGroupsMutator)(NSArray *, NSString *);

@interface UATagGroupsRegistrar()

/**
 * The tag groups API client.
 */
@property (nonatomic, strong) UATagGroupsAPIClient *tagGroupsAPIClient;

/**
 * The queue on which to serialize tag groups operations.
 */
@property (nonatomic,strong) NSOperationQueue *operationQueue;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

@end

@implementation UATagGroupsRegistrar

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue {
    self = [super initWithDataStore:dataStore];
    if (self) {
        self.dataStore = dataStore;
        
        self.tagGroupsAPIClient = apiClient;
        self.tagGroupsAPIClient.enabled = self.componentEnabled;
        
        self.operationQueue = operationQueue;
        self.operationQueue.maxConcurrentOperationCount = 1;

        [self migrateDataStoreKeys];
    }
    return self;
}

+ (instancetype)tagGroupsRegistrarWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore
                                                 apiClient:[UATagGroupsAPIClient clientWithConfig:config]
                                            operationQueue:[[NSOperationQueue alloc] init]];
}

+ (instancetype)tagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore apiClient:(UATagGroupsAPIClient *)apiClient operationQueue:(NSOperationQueue *)operationQueue {
    return [[UATagGroupsRegistrar alloc] initWithDataStore:dataStore apiClient:apiClient operationQueue:operationQueue];
}

- (void)dealloc {
    [self.operationQueue cancelAllOperations];
}

- (NSString *)prefixForType:(UATagGroupsType)type {
    switch(type) {
        case UATagGroupsTypeChannel:
            return UAPushTagGroupsKeyPrefix;
        case UATagGroupsTypeNamedUser:
            return UANamedUserTagGroupsKeyPrefix;
    }
}

- (NSString *)formattedKey:(NSString *)actionName type:(UATagGroupsType)type {
    return [NSString stringWithFormat:@"%@%@", [self prefixForType:type], actionName];
}

- (NSString *)addTagGroupsSettingsKey:(UATagGroupsType)type {
    return [self formattedKey:@"AddTagGroups" type:type];
}

- (NSString *)removeTagGroupsSettingsKey:(UATagGroupsType)type {
    return [self formattedKey:@"RemoveTagGroups" type:type];
}

- (NSString *)tagGroupsMutationsKey:(UATagGroupsType)type {
    return [self formattedKey:@"TagGroupsMutations" type:type];
}

- (void)migrateDataStoreKeys {
    for (NSNumber *typeNumber in @[@(UATagGroupsTypeNamedUser), @(UATagGroupsTypeChannel)]) {
        UATagGroupsType type = typeNumber.unsignedIntegerValue;
        [self.dataStore migrateTagGroupSettingsForAddTagsKey:[self addTagGroupsSettingsKey:type]
                                               removeTagsKey:[self removeTagGroupsSettingsKey:type]
                                                      newKey:[self tagGroupsMutationsKey:type]];
    }
}

- (void)updateTagGroupsForID:(NSString *)identifier type:(UATagGroupsType)type {
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
    
    [self uploadNextTagGroupMutationForID:identifier backgroundTaskIdentifier:backgroundTaskIdentifier type:type];
}

// this method runs asynchronously on the operation queue
- (void)uploadNextTagGroupMutationForID:(NSString *)identifier
               backgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier
                                   type:(UATagGroupsType)type {

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

        NSString *tagGroupsMutationsKey = [self tagGroupsMutationsKey:type];
        
        // collapse mutations
        [self.dataStore collapseTagGroupsMutationForKey:tagGroupsMutationsKey];
        
        // peek at top mutation
        UATagGroupsMutation *mutation = [self.dataStore peekTagGroupsMutationForKey:tagGroupsMutationsKey];
        
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
                [self.dataStore popTagGroupsMutationForKey:tagGroupsMutationsKey];
                if (operation.isCancelled) {
                    [self endBackgroundTask:backgroundTaskIdentifier];
                } else {
                    // upload next tag group mutation
                    [self uploadNextTagGroupMutationForID:identifier backgroundTaskIdentifier:backgroundTaskIdentifier type:type];
                }
            } else if (status == 400 || status == 403) {
                [self.dataStore popTagGroupsMutationForKey:tagGroupsMutationsKey];
                [self endBackgroundTask:backgroundTaskIdentifier];
            }
            [operation finish];
        };
        
        [self.tagGroupsAPIClient updateTagGroupsForId:identifier
                                    tagGroupsMutation:mutation
                                                 type:type
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

- (UATagGroupsMutator)tagGroupsMutator:(UATagGroupsMutationFactory)factory
                           requireTags:(BOOL)requireTags
                                  type:(UATagGroupsType)type {
    return ^(NSArray *tags, NSString *tagGroupID) {
        NSArray *normalizedTags = [UATagUtils normalizeTags:tags];
        NSString *normalizedTagGroupID = [UATagUtils normalizeTagGroupID:tagGroupID];

        if (requireTags && !normalizedTags.count) {
            return;
        }

        if (!normalizedTagGroupID.length) {
            return;
        }

        UATagGroupsMutation *mutation = factory(normalizedTags, normalizedTagGroupID);
        NSString *tagGroupsMutationsKey = [self tagGroupsMutationsKey:type];

        // rest runs on the operation queue
        [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            [self.dataStore addTagGroupsMutation:mutation forKey:tagGroupsMutationsKey];
        }]];
    };
}

- (UATagGroupsMutator) addTagsMutator:(UATagGroupsType)type {
    return [self tagGroupsMutator:^(NSArray *normalizedTags, NSString *normalizedTagGroupID) {
        return [UATagGroupsMutation mutationToAddTags:normalizedTags
                                                group:normalizedTagGroupID];
    } requireTags:YES type:type];
}

- (UATagGroupsMutator) removeTagsMutator:(UATagGroupsType)type {
    return [self tagGroupsMutator:^(NSArray *normalizedTags, NSString *normalizedTagGroupID){
        return [UATagGroupsMutation mutationToRemoveTags:normalizedTags
                                                   group:normalizedTagGroupID];
    } requireTags:YES type:type];
}

- (UATagGroupsMutator) setTagsMutator:(UATagGroupsType)type {
    return [self tagGroupsMutator:^(NSArray *normalizedTags, NSString *normalizedTagGroupID){
        return [UATagGroupsMutation mutationToSetTags:normalizedTags
                                                group:normalizedTagGroupID];
    } requireTags:NO type:type];
}

// This method may finish asynchronously on the operation queue
- (void)addTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type {
    [self addTagsMutator:type](tags, tagGroupID);
}

// This method may finish asynchronously on the operation queue
- (void)removeTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type {
    [self removeTagsMutator:type](tags, tagGroupID);
}

// This method may finish asynchronously on the operation queue
- (void)setTags:(NSArray *)tags group:(NSString *)tagGroupID type:(UATagGroupsType)type {
    [self setTagsMutator:type](tags, tagGroupID);
}

- (void)clearAllPendingTagUpdates:(UATagGroupsType) type {
    NSString *tagGroupsMutationsKey = [self tagGroupsMutationsKey:type];

    [self.operationQueue cancelAllOperations];
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.dataStore removeObjectForKey:tagGroupsMutationsKey];
    }]];
}

- (void)onComponentEnableChange {
    self.tagGroupsAPIClient.enabled = self.componentEnabled;
}


@end
