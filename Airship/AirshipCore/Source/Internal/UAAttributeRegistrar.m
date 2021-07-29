/* Copyright Airship and Contributors */

#import "UAAttributeRegistrar+Internal.h"
#import "UAPersistentQueue+Internal.h"
#import "UAAttributeAPIClient+Internal.h"
#import "UAAttributeMutations+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UAUtils.h"

static NSString *const ChannelPersistentQueueKey = @"com.urbanairship.channel_attributes.registrar_persistent_queue_key";
static NSString *const NamedUserPersistentQueueKey = @"com.urbanairship.named_user_attributes.registrar_persistent_queue_key";

@interface UAAttributeRegistrar()
@property(nonatomic, strong) UAPersistentQueue *pendingAttributeMutationsQueue;
@property(nonatomic, strong) UAAttributeAPIClient *client;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) UIApplication *application;
@property(atomic, copy) NSString *identifier;
@end

@implementation UAAttributeRegistrar

+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {

    UAPersistentQueue *queue = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                           key:ChannelPersistentQueueKey];

    return [[UAAttributeRegistrar alloc] initWithAPIClient:[UAAttributeAPIClient channelClientWithConfig:config]
                                           persistentQueue:queue
                                               application:[UIApplication sharedApplication]];
}

+ (instancetype)namedUserRegistrarWithConfig:(UARuntimeConfig *)config
                                   dataStore:(UAPreferenceDataStore *)dataStore NS_EXTENSION_UNAVAILABLE("Method not available in app extensions") {

    UAPersistentQueue *queue = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                           key:NamedUserPersistentQueueKey];

    return [[UAAttributeRegistrar alloc] initWithAPIClient:[UAAttributeAPIClient namedUserClientWithConfig:config]
                                           persistentQueue:queue
                                               application:[UIApplication sharedApplication]];
}

+ (instancetype)registrarWithAPIClient:(UAAttributeAPIClient *)APIClient
                       persistentQueue:(UAPersistentQueue *)persistentQueue
                           application:(UIApplication *)application {
    return [[UAAttributeRegistrar alloc] initWithAPIClient:APIClient
                                           persistentQueue:persistentQueue
                                               application:application];
}

- (instancetype)initWithAPIClient:(UAAttributeAPIClient *)APIClient
                  persistentQueue:(UAPersistentQueue *)persistentQueue
                      application:(UIApplication *)application {
    self = [super init];
    if (self) {
        self.application = application;
        self.client = APIClient;
        self.pendingAttributeMutationsQueue = persistentQueue;
    }

    return self;
}

- (void)savePendingMutations:(UAAttributePendingMutations *)mutations {
    if (mutations.mutationsPayload.count == 0) {
        UA_LTRACE(@"UAAttributeRegistrar - Attribute mutation compression resulted in no mutations, skipping save.");
        return;
    }

    [self.pendingAttributeMutationsQueue addObject:mutations];
}

- (void)clearPendingMutations {
    [self.pendingAttributeMutationsQueue clear];
}

- (void)collapseQueuedPendingMutations {
    [self.pendingAttributeMutationsQueue collapse:^NSArray<id<NSSecureCoding>> * (NSArray<id<NSSecureCoding>> *mutations) {
        if (mutations.count == 0) {
            return mutations;
        }

        return @[[UAAttributePendingMutations collapseMutations:(NSArray<UAAttributePendingMutations *>*)mutations]];
    }];
}

- (UADisposable *)updateAttributesWithCompletionHandler:(void(^)(UAAttributeUploadResult result))completionHandler {
    UAAttributePendingMutations *mutations;
    NSString *identifier;

    @synchronized (self) {
        // collapse mutations
        [self collapseQueuedPendingMutations];

        // peek mutations
        mutations = (UAAttributePendingMutations *)[self.pendingAttributeMutationsQueue peekObject];
        identifier = self.identifier;
    }

    if (!identifier || !mutations) {
        completionHandler(UAAttributeUploadResultUpToDate);
        return nil;
    }

    UA_WEAKIFY(self);
    void (^apiCompletionBlock)(UAHTTPResponse *, NSError *) = ^void (UAHTTPResponse *response, NSError *error) {
        UA_STRONGIFY(self);

        if (response.isSuccess) {
            UA_LDEBUG(@"Update of %@ succeeded", mutations);
            [self popPendingMutations:mutations identifier:identifier];
            [self.delegate uploadedAttributeMutations:mutations identifier:identifier];
            completionHandler(UAAttributeUploadResultFinished);
        } else if (error || response.isServerError || response.status == 429) {
            UA_LDEBUG(@"Update of %@ failed with response: %@ error: %@", mutations, response, error);
            completionHandler(UAAttributeUploadResultFailed);
        } else {
            // Unrecoverable failure - pop mutation
            UA_LINFO(@"Update of %@ failed with response: %@", mutations, response);
            [self popPendingMutations:mutations identifier:identifier];
            completionHandler(UAAttributeUploadResultFinished);
        }
    };

    return [self.client updateWithIdentifier:identifier
                          attributeMutations:mutations
                           completionHandler:apiCompletionBlock];
}

- (void)popPendingMutations:(UAAttributePendingMutations *)mutations
                 identifier:(NSString *)identifier {
    @synchronized (self) {
        // Pop the mutation if it is what we expect and the identifier has not changed
        if ([mutations isEqual:self.pendingAttributeMutationsQueue.peekObject] && [identifier isEqualToString:self.identifier]) {
            [self.pendingAttributeMutationsQueue popObject];
        }
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

- (UAAttributePendingMutations *)pendingMutations {
    NSArray *combined = [self.pendingAttributeMutationsQueue objects];
    return [UAAttributePendingMutations collapseMutations:combined];
}

@end

