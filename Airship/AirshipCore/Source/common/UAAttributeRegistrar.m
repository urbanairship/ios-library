/* Copyright Airship and Contributors */

#import "UAAttributeRegistrar+Internal.h"
#import "UAPersistentQueue+Internal.h"
#import "UAAttributeAPIClient+Internal.h"
#import "UAAttributeMutations+Internal.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAAsyncOperation.h"
#import "UAUtils.h"
#import "UADate.h"
#import "UAComponent.h"

NSString *const PersistentQueueKey = @"com.urbanairship.channel_attributes.registrar_persistent_queue_key";

@interface UAAttributeRegistrar()
@property(nonatomic, strong) UAPersistentQueue *pendingAttributeMutationsQueue;
@property(nonatomic, strong) UAAttributeAPIClient *client;
@property(nonatomic, strong) UAPreferenceDataStore *dataStore;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) UIApplication *application;
@property(nonatomic, strong) UADate *date;
@end

@implementation UAAttributeRegistrar

+ (instancetype)registrarWithConfig:(UARuntimeConfig *)config
                          dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAAttributeRegistrar alloc] initWithDataStore:dataStore
                                                 apiClient:[UAAttributeAPIClient clientWithConfig:config]
                                            operationQueue:[[NSOperationQueue alloc] init]
                                               application:[UIApplication sharedApplication]
                                                      date:[[UADate alloc] init]];
}

+ (instancetype)registrarWithDataStore:(UAPreferenceDataStore *)dataStore
                             apiClient:(UAAttributeAPIClient *)apiClient
                        operationQueue:(NSOperationQueue *)operationQueue
                           application:(UIApplication *)application
                                  date:(UADate *)date {
    return [[UAAttributeRegistrar alloc] initWithDataStore:dataStore
                                                 apiClient:apiClient
                                            operationQueue:operationQueue
                                               application:application
                                                      date:date];
}

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                        apiClient:(UAAttributeAPIClient *)apiClient
                   operationQueue:(NSOperationQueue *)operationQueue
                      application:application
                             date:date {
    self = [super initWithDataStore:dataStore];

    if (self) {
        self.dataStore = dataStore;
        self.application = application;
        self.client = apiClient;
        self.client.enabled = self.componentEnabled;
        self.date = date;
        self.pendingAttributeMutationsQueue = [UAPersistentQueue persistentQueueWithDataStore:dataStore key:PersistentQueueKey];
        self.operationQueue = operationQueue;
        self.operationQueue.maxConcurrentOperationCount = 1;
    }

    return self;
}

-(void)dealloc {
    [self.operationQueue cancelAllOperations];
}

- (void)savePendingMutations:(UAAttributePendingMutations *)mutations {
    if (mutations.mutationsPayload.count == 0) {
        UA_LTRACE(@"UAAttributeRegistrar - Attribute mutation compression resulted in no mutations, skipping save.");
        return;
    }

    [self.pendingAttributeMutationsQueue addObject:mutations];
}

- (void)deletePendingMutations {
    [self.pendingAttributeMutationsQueue clear];
}

- (void)collapseQueuedPendingMutations {
    UAPersistentQueue *queue = self.pendingAttributeMutationsQueue;
    NSArray<UAAttributePendingMutations *> *mutationsToCollapse = [[queue objects] mutableCopy];

    if (mutationsToCollapse.count == 0) {
        // Nothing in the queue to collapse
        return;
    }

    UAAttributePendingMutations *mutations = [UAAttributePendingMutations collapseMutations:mutationsToCollapse];
    [queue setObjects:@[mutations]];
}

- (void)updateAttributesForChannel:(NSString *)identifier {
    if (!self.componentEnabled || !self.isDataOptIn) {
        return;
    }

    UAAsyncOperation *operation = [UAAsyncOperation operationWithBlock:^(UAAsyncOperation *operation) {
        UA_WEAKIFY(self);
        __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = [self.application beginBackgroundTaskWithExpirationHandler:^{
            UA_STRONGIFY(self);

            UA_LTRACE(@"UAAttributeRegistrar - Attribute mutation background task expired.");
            [self.client cancelAllRequests];
            [self endBackgroundTask:backgroundTaskIdentifier];
            [operation finish];
        }];

        if (backgroundTaskIdentifier == UIBackgroundTaskInvalid) {
            UA_LTRACE("UAAttributeRegistrar - Background task unavailable, skipping attribute mutation update.");
            [operation finish];
            return;
        }

        // Collapse queued pending mutations
        [self collapseQueuedPendingMutations];

        if (self.pendingAttributeMutationsQueue.objects.count == 0) {
            [self endBackgroundTask:backgroundTaskIdentifier];
            [operation finish];
            return;
        }

        UAAttributePendingMutations *nextPendingMutation = (UAAttributePendingMutations *)[self.pendingAttributeMutationsQueue peekObject];

        [self.client updateChannel:identifier withAttributePayload:nextPendingMutation.payload onSuccess:^{
            // Success - pop uploaded mutation
            [self.pendingAttributeMutationsQueue popObject];

            // Continue updating attributes for channel if operation has not been canceled and there are remaining mutations to upload
            if (!operation.isCancelled && self.pendingAttributeMutationsQueue.objects.count > 0) {
                [self updateAttributesForChannel:identifier];
            }

            [self endBackgroundTask:backgroundTaskIdentifier];
            [operation finish];
        } onFailure:^(NSUInteger statusCode) {
            UA_LDEBUG("UAAttributeRegistrar - update attribute request failed with status code:%lu", (unsigned long)statusCode);

            if (statusCode == 400 || statusCode == 403) {
                // Unrecoverable failure - pop mutation and end the background task
                [self.pendingAttributeMutationsQueue popObject];
                [self endBackgroundTask:backgroundTaskIdentifier];
            }

            [operation finish];
        }];
    }];

    [self.operationQueue addOperation:operation];
}

- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)backgroundTaskIdentifier {
   if (backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
       [self.application endBackgroundTask:backgroundTaskIdentifier];
   }
}

- (void)onComponentEnableChange {
    self.client.enabled = self.componentEnabled;
}

- (BOOL)isDataOptIn {
    return [self.dataStore boolForKey:UAAirshipDataOptInKey];
}

@end
