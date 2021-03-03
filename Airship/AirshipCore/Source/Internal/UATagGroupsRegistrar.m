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

- (UADisposable *)updateTagGroupsWithTask:(id<UATask>)task completionHandler:(void(^)(BOOL completed))completionHandler {
    @synchronized (self) {
        if (!self.enabled) {
            [task taskCompleted];
            completionHandler(NO);
            return nil;
        }
    }
    
    return [self uploadNextTagGroupMutationWithTask:task completionHandler:completionHandler];
}

- (void)popPendingMutation:(UATagGroupsMutation *)mutation identifier:(NSString *)identifier {
    @synchronized (self) {
        // Pop the mutation if it is what we expect and the identifier has not changed
        if ([mutation isEqual:self.pendingTagGroupStore.peekPendingMutation] && [identifier isEqualToString:self.identifier]) {
            [self.pendingTagGroupStore popPendingMutation];
        }
    }
}

- (UADisposable *)uploadNextTagGroupMutationWithTask:(id<UATask>)task completionHandler:(void(^)(BOOL completed))completionHandler {
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
        // no upload work to do - end task, if necessary, and finish operation
        [task taskCompleted];
        completionHandler(NO);
        return nil;
    }

    UA_WEAKIFY(self);
    void (^apiCompletionBlock)(NSError *) = ^void(NSError *error) {
        UA_STRONGIFY(self);
        if (!error) {
            // Success - pop uploaded mutation and store the transaction record
            [self popPendingMutation:mutation identifier:identifier];
            [self.delegate uploadedTagGroupsMutation:mutation identifier:identifier];
            [task taskCompleted];
            completionHandler(YES);
        } else if (error.domain == UATagGroupsAPIClientErrorDomain && error.code == UATagGroupsAPIClientErrorUnrecoverableStatus) {
            // Unrecoverable failure - pop mutation and end the task
            [self popPendingMutation:mutation identifier:identifier];
            [task taskCompleted];
            completionHandler(YES);
        } else {
            [task taskFailed];
            completionHandler(NO);
        }
    };

    return [self.tagGroupsAPIClient updateTagGroupsForId:identifier
                                tagGroupsMutation:mutation
                                completionHandler:apiCompletionBlock];
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
