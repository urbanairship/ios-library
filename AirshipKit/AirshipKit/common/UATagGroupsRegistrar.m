/* Copyright Urban Airship and Contributors */

#import "UATagGroupsRegistrar+Internal.h"

#import "UATagGroupsMutation+Internal.h"
#import "UATagGroupsAPIClient+Internal.h"
#import "UATagUtils+Internal.h"
#import "UAAsyncOperation+Internal.h"
#import "UATagGroupsMutationHistory+Internal.h"

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

/**
 * The mutation history.
 */
@property (nonatomic, strong) UATagGroupsMutationHistory *mutationHistory;

/**
 * The application.
 */
@property (nonatomic, strong) UIApplication *application;

@end

@implementation UATagGroupsRegistrar

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                  mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                              apiClient:(UATagGroupsAPIClient *)apiClient
                         operationQueue:(NSOperationQueue *)operationQueue
                      application:application {
    
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.dataStore = dataStore;
        self.application = application;
        self.mutationHistory = mutationHistory;
        self.tagGroupsAPIClient = apiClient;
        self.tagGroupsAPIClient.enabled = self.componentEnabled;
        
        self.operationQueue = operationQueue;
        self.operationQueue.maxConcurrentOperationCount = 1;
    }

    return self;
}

+ (instancetype)tagGroupsRegistrarWithConfig:(UAConfig *)config
                                   dataStore:(UAPreferenceDataStore *)dataStore
                             mutationHistory:(UATagGroupsMutationHistory *)mutationHistory {

    return [[self alloc] initWithDataStore:dataStore
                           mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                                 apiClient:[UATagGroupsAPIClient clientWithConfig:config]
                            operationQueue:[[NSOperationQueue alloc] init]
                               application:[UIApplication sharedApplication]];
}

+ (instancetype)tagGroupsRegistrarWithDataStore:(UAPreferenceDataStore *)dataStore
                                mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                                      apiClient:(UATagGroupsAPIClient *)apiClient
                                 operationQueue:(NSOperationQueue *)operationQueue
                                    application:(UIApplication *)application {

    return [[self alloc] initWithDataStore:dataStore
                           mutationHistory:(UATagGroupsMutationHistory *)mutationHistory
                                 apiClient:apiClient
                            operationQueue:operationQueue
                               application:application];
}

- (void)dealloc {
    [self.operationQueue cancelAllOperations];
}

- (void)updateTagGroupsForID:(NSString *)identifier type:(UATagGroupsType)type {
    if (!self.componentEnabled) {
        return;
    }
    
    UA_WEAKIFY(self);
    
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [self.application beginBackgroundTaskWithExpirationHandler:^{
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

        // collapse mutations
        [self.mutationHistory collapsePendingMutations:type];
        
        // peek at top mutation
        UATagGroupsMutation *mutation = [self.mutationHistory peekPendingMutation:type];
        
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
                // Success - pop uploaded mutation and store the transaction record
                UATagGroupsMutation *mutation = [self.mutationHistory popPendingMutation:type];

                [self.mutationHistory addSentMutation:mutation date:[NSDate date]];

                // Try to upload more mutations as long as the operation hasn't been canceled
                if (operation.isCancelled) {
                    [self endBackgroundTask:backgroundTaskIdentifier];
                } else {
                    [self uploadNextTagGroupMutationForID:identifier backgroundTaskIdentifier:backgroundTaskIdentifier type:type];
                }
            } else if (status == 400 || status == 403) {
                // Unrecoverable failure - pop mutation and end the task
                [self.mutationHistory popPendingMutation:type];
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
        [self.application endBackgroundTask:backgroundTaskIdentifier];
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

        // rest runs on the operation queue
        [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
            [self.mutationHistory addPendingMutation:mutation type:type];
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
    [self.operationQueue cancelAllOperations];
    [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        [self.mutationHistory clearPendingMutations:type];
    }]];
}

- (void)onComponentEnableChange {
    self.tagGroupsAPIClient.enabled = self.componentEnabled;
}

@end
