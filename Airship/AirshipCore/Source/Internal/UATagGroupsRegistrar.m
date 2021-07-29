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

- (instancetype)initWithPendingTagGroupStore:(UAPendingTagGroupStore *)pendingTagGroupStore
                                   apiClient:(UATagGroupsAPIClient *)apiClient
                                 application:application {
    
    self = [super init];

    if (self) {
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

+ (instancetype)channelTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config  dataStore:(UAPreferenceDataStore *)dataStore NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {

    UAPendingTagGroupStore *pendingTagGroupStore = [UAPendingTagGroupStore channelHistoryWithDataStore:dataStore];
    UATagGroupsAPIClient *client =  [UATagGroupsAPIClient channelClientWithConfig:config];

    return [[self alloc] initWithPendingTagGroupStore:pendingTagGroupStore
                                            apiClient:client
                                          application:[UIApplication sharedApplication]];
}

+ (instancetype)namedUserTagGroupsRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {

    UAPendingTagGroupStore *pendingTagGroupStore = [UAPendingTagGroupStore namedUserHistoryWithDataStore:dataStore];
    UATagGroupsAPIClient *client =  [UATagGroupsAPIClient namedUserClientWithConfig:config];

    return [[self alloc] initWithPendingTagGroupStore:pendingTagGroupStore
                                            apiClient:client
                                          application:[UIApplication sharedApplication]];
}

- (UADisposable *)updateTagGroupsWithCompletionHandler:(void(^)(UATagGroupsUploadResult result))completionHandler {
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
        completionHandler(UATagGroupsUploadResultUpToDate);
        return nil;
    }

    UA_WEAKIFY(self);
    void (^apiCompletionBlock)(UAHTTPResponse *, NSError *) = ^void (UAHTTPResponse *response, NSError *error) {
        UA_STRONGIFY(self);

        if (response.isSuccess) {
            UA_LDEBUG(@"Update of %@ succeeded", mutation);
            [self popPendingMutation:mutation identifier:identifier];
            [self.delegate uploadedTagGroupsMutation:mutation identifier:identifier];
            completionHandler(UATagGroupsUploadResultFinished);
        } else if (error || response.isServerError || response.status == 429) {
            UA_LDEBUG(@"Update of %@ failed with response: %@ error: %@", mutation, response, error);
            completionHandler(UATagGroupsUploadResultFailed);
        } else {
            // Unrecoverable failure - pop mutation
            UA_LINFO(@"Update of %@ failed with response: %@", mutation, response);
            [self popPendingMutation:mutation identifier:identifier];
            completionHandler(UATagGroupsUploadResultFinished);
        }
    };

    return [self.tagGroupsAPIClient updateTagGroupsForId:identifier
                                       tagGroupsMutation:mutation
                                       completionHandler:apiCompletionBlock];
}

- (void)popPendingMutation:(UATagGroupsMutation *)mutation identifier:(NSString *)identifier {
    @synchronized (self) {
        // Pop the mutation if it is what we expect and the identifier has not changed
        if ([mutation isEqual:self.pendingTagGroupStore.peekPendingMutation] && [identifier isEqualToString:self.identifier]) {
            [self.pendingTagGroupStore popPendingMutation];
        }
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

- (void)setIdentifier:(NSString *)identifier clearPendingOnChange:(BOOL)clearPendingOnChange {
    @synchronized (self) {
        if (clearPendingOnChange && ![identifier isEqualToString:self.identifier]) {
            [self clearPendingMutations];
        }
        
        self.identifier = identifier;
    }
}

@end
