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
@property(atomic, assign) BOOL updating;
@end

@implementation UAAttributeRegistrar

@synthesize enabled = _enabled;

+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore {

    UAPersistentQueue *queue = [UAPersistentQueue persistentQueueWithDataStore:dataStore
                                                                           key:ChannelPersistentQueueKey];

    return [[UAAttributeRegistrar alloc] initWithAPIClient:[UAAttributeAPIClient channelClientWithConfig:config]
                                           persistentQueue:queue
                                               application:[UIApplication sharedApplication]];
}

+ (instancetype)namedUserRegistrarWithConfig:(UARuntimeConfig *)config
                                   dataStore:(UAPreferenceDataStore *)dataStore {

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
        self.enabled = YES;
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
    [self.pendingAttributeMutationsQueue collapse:^NSArray<id<NSCoding>> * (NSArray<id<NSCoding>> *mutations) {
        if (mutations.count == 0) {
            return mutations;
        }

        return @[[UAAttributePendingMutations collapseMutations:(NSArray<UAAttributePendingMutations *>*)mutations]];
    }];
}

- (void)updateAttributes {
    @synchronized (self) {
        if (!self.enabled) {
            return;
        }

        if (self.updating) {
            UA_LTRACE(@"Skipping attribute update, request already in flight");
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

    [self uploadNextMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
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

- (void)uploadNextMutationWithBackgroundTaskIdentifier:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
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
        // no upload work to do - end background task, if necessary, and finish operation
        [self endUploading:backgroundTaskIdentifier];
        return;
    }

    UA_WEAKIFY(self);
    void (^apiCompletionBlock)(NSError *) = ^void (NSError *error) {
        UA_STRONGIFY(self);
        if (!error) {
            // Success - pop mutation
            [self popPendingMutations:mutations identifier:identifier];
            [self.delegate uploadedAttributeMutations:mutations identifier:identifier];
            [self uploadNextMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
        } else if (error.domain == UAAttributeAPIClientErrorDomain && error.code == UAAttributeAPIClientErrorUnrecoverableStatus) {
            // Unrecoverable failure - pop mutation
            UA_LERR(@"Unable to upload mutations: %@. Dropping.", mutations);
            [self popPendingMutations:mutations identifier:identifier];
            [self uploadNextMutationWithBackgroundTaskIdentifier:backgroundTaskIdentifier];
        } else {
            UA_LINFO(@"Update of %@ failed with error: %@", mutations, error);
            [self endUploading:backgroundTaskIdentifier];
        }
    };

    [self.client updateWithIdentifier:identifier
                   attributeMutations:mutations
                    completionHandler:apiCompletionBlock];
}

- (UIBackgroundTaskIdentifier)beginUploading {
    UA_WEAKIFY(self);
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [self.application beginBackgroundTaskWithExpirationHandler:^{
        UA_STRONGIFY(self);

        UA_LTRACE(@"Attribute background task expired.");
        [self.client cancelAllRequests];

        [self endUploading:backgroundTaskIdentifier];
    }];

    return backgroundTaskIdentifier;
}

- (void)endUploading:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
    if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [self.application endBackgroundTask:backgroundTaskIdentifier];
    }

    @synchronized (self) {
        self.updating = NO;
    }
}

- (void)setEnabled:(BOOL)enabled {
    @synchronized (self) {
        _enabled = enabled;
        self.client.enabled = enabled;
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

- (UAAttributePendingMutations *)pendingMutations {
    NSArray *combined = [self.pendingAttributeMutationsQueue objects];
    return [UAAttributePendingMutations collapseMutations:combined];
}

@end

