/* Copyright Airship and Contributors */

#import "UIKit/UIKit.h"

#import "UATaskManager.h"
#import "UAGlobal.h"
#import "UADispatcher.h"
#import "UAAppStateTracker.h"
#import "UANetworkMonitor+Internal.h"
#import "UATask.h"
#import "UAExpirableTask+Internal.h"
#import "UATaskLauncher+Internal.h"
#import "UATaskRequest+Internal.h"

#define kUATaskManagerInitialBackOff 30.0
#define kUATaskManagerMaxBackOff 120.0
#define kUATaskManagerMinBackgroundTime 30.0

@interface UATaskManager()
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<UATaskLauncher *> *> *launcherMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<UATaskRequest *> *> *currentRequests;
@property(nonatomic, strong) NSMutableArray<UATaskRequest *> *waitingConditionsRequests;
@property(nonatomic, strong) NSMutableArray<UATaskRequest *> *retryingRequests;
@property(nonatomic, strong) UIApplication *application;
@property(nonatomic, strong) UADispatcher *dispatcher;
@property(nonatomic, strong) UANetworkMonitor *networkMonitor;
@end

@implementation UATaskManager

- (instancetype)initWithApplication:(UIApplication *)application
                 notificationCenter:(NSNotificationCenter *)notificationCenter
                         dispatcher:(UADispatcher *)dispatcher
                     networkMonitor:(UANetworkMonitor *)networkMonitor {

    self = [super init];
    if (self) {
        self.launcherMap = [NSMutableDictionary dictionary];
        self.currentRequests = [NSMutableDictionary dictionary];
        self.waitingConditionsRequests = [NSMutableArray array];
        self.retryingRequests = [NSMutableArray array];
        self.application = application;
        self.dispatcher = dispatcher;
        self.networkMonitor = networkMonitor;

        [notificationCenter addObserver:self
                               selector:@selector(didBecameActive)
                                   name:UAApplicationDidBecomeActiveNotification
                                      object:nil];

        [notificationCenter addObserver:self
                               selector:@selector(didEnterBackground)
                                   name:UAApplicationDidEnterBackgroundNotification
                                 object:nil];

        if (@available(ios 12.0, tvOS 12.0, *)) {
            UA_WEAKIFY(self)
            [self.networkMonitor connectionUpdates:^(BOOL connected) {
                UA_STRONGIFY(self)
                if (connected) {
                    [self retryWaitingConditions];
                }
            }];
        }
    }

    return self;
}

+ (instancetype)taskManagerWithApplication:(UIApplication *)application
                        notificationCenter:(NSNotificationCenter *)notificationCenter
                                dispatcher:(UADispatcher *)dispatcher
                            networkMonitor:(UANetworkMonitor *)networkMonitor {

    return [[self alloc] initWithApplication:application
                          notificationCenter:notificationCenter
                                  dispatcher:dispatcher
                              networkMonitor:networkMonitor];
}

+ (instancetype)shared {
    static UATaskManager *sharedTaskManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedTaskManager = [[UATaskManager alloc] initWithApplication:[UIApplication sharedApplication]
                                                    notificationCenter:[NSNotificationCenter defaultCenter]
                                                            dispatcher:[UADispatcher globalDispatcher]
                                                        networkMonitor:[[UANetworkMonitor alloc] init]];
    });
    return sharedTaskManager;
}

- (void)registerForTaskWithIDs:(NSArray<NSString *> *)identifiers
                    dispatcher:(nullable UADispatcher *)dispatcher
                 launchHandler:(void (^)(id<UATask>))launchHandler {

    @synchronized (self.launcherMap) {
        for (NSString *identifier in identifiers) {
            [self registerForTaskWithID:identifier dispatcher:dispatcher launchHandler:launchHandler];
        }
    }
}

- (void)registerForTaskWithID:(NSString *)identifier
                   dispatcher:(nullable UADispatcher *)dispatcher
                launchHandler:(void (^)(id<UATask>))launchHandler {

    @synchronized (self.launcherMap) {
        UATaskLauncher *launcher = [UATaskLauncher launcherWithDispatcher:dispatcher
                                                            launchHandler:launchHandler];
        if (!self.launcherMap[identifier]) {
            self.launcherMap[identifier] = [NSMutableArray array];
        }
        [self.launcherMap[identifier] addObject:launcher];
    }
}

- (void)enqueueRequestWithID:(NSString *)taskID
                     options:(UATaskRequestOptions *)options {
    [self enqueueRequestWithID:taskID options:options initialDelay:0];
}


- (void)enqueueRequestWithID:(NSString *)taskID
                     options:(UATaskRequestOptions *)options
                initialDelay:(NSTimeInterval)initialDelay {

    NSArray *launchers;
    @synchronized (self.launcherMap)  {
        launchers = self.launcherMap[taskID];
    }

    if (!launchers.count) {
        UA_LERR(@"No registered launchers for task %@", taskID);
        return;
    }

    NSMutableArray *requests = [NSMutableArray array];
    for (UATaskLauncher *launcher in launchers) {
        UATaskRequest *request = [UATaskRequest requestWithID:taskID
                                                      options:options
                                                     launcher:launcher];
        [requests addObject:request];
    }

    @synchronized (self.currentRequests) {
        NSMutableArray *requestsByID = self.currentRequests[taskID] ?: [NSMutableArray array];
        self.currentRequests[taskID] = requestsByID;

        switch (options.conflictPolicy) {
            case UATaskConflictPolicyKeep:
                if (requestsByID.count) {
                    UA_LTRACE(@"Request already scheduled, ignoring new request %@.", taskID);
                    return;
                }
                [requestsByID addObjectsFromArray:requests];
                break;

            case UATaskConflictPolicyAppend:
                [requestsByID addObjectsFromArray:requests];
                break;

            case UATaskConflictPolicyReplace:
                if (requestsByID.count) {
                    UA_LTRACE(@"Request already scheduled, replacing with new request %@.", taskID);
                    [requestsByID removeAllObjects];
                }
                [requestsByID addObjectsFromArray:requests];
                break;
        }
    }

    [self initiateRequests:requests initialDelay:initialDelay];
}

- (void)initiateRequests:(NSArray<UATaskRequest *> *)requests initialDelay:(NSTimeInterval)initialDelay {
    if (initialDelay) {
        UA_WEAKIFY(self)
        [self.dispatcher dispatchAfter:initialDelay block:^{
            UA_STRONGIFY(self)
            for (UATaskRequest *request in requests) {
                [self attemptRequest:request nextBackOff:kUATaskManagerInitialBackOff];
            }
        }];
    } else {
        for (UATaskRequest *request in requests) {
            [self attemptRequest:request nextBackOff:kUATaskManagerInitialBackOff];
        }
    }
}

- (void)retryRequest:(UATaskRequest *)request delay:(NSTimeInterval)delay {
    @synchronized (self.retryingRequests) {
        [self.retryingRequests addObject:request];
    }

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAfter:delay block:^{
        UA_STRONGIFY(self)

        @synchronized (self.retryingRequests) {
            if ([self.retryingRequests containsObject:request]) {
                [self.retryingRequests removeObject:request];
            } else {
                return;
            }
        }

        [self attemptRequest:request nextBackOff:[UATaskManager nextBackOff:delay]];
    }];
}

- (void)attemptRequest:(UATaskRequest *)request nextBackOff:(NSTimeInterval)nextBackOff {
    if (![self isRequestCurrent:request]) {
        return;
    }

    __block UIBackgroundTaskIdentifier backgroundTask;

    UA_WEAKIFY(self)
    __block UAExpirableTask *task = [UAExpirableTask taskWithID:request.taskID
                                                        options:request.options
                                              completionHandler:^(BOOL result) {
        UA_STRONGIFY(self)
        if ([self isRequestCurrent:request]) {
            if (result) {
                UA_LTRACE(@"Task %@ finished.", request.taskID);
                [self requestFinished:request];
            } else {
                UA_LTRACE(@"Task %@ failed, will retry in %f seconds", request.taskID, nextBackOff);
                [self retryRequest:request delay:nextBackOff];
            }
        }

        if (backgroundTask != UIBackgroundTaskInvalid) {
            [self.application endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    NSString *taskName = [NSString stringWithFormat:@"UATaskManager %@", request.taskID];
    backgroundTask = [self.application beginBackgroundTaskWithName:taskName
                                                 expirationHandler:^{
        [task expire];
    }];

    if (backgroundTask != UIBackgroundTaskInvalid && [self checkRequestRequirements:request]) {
        [request.launcher launch:task];
    } else {
        @synchronized (self.waitingConditionsRequests) {
            [self.waitingConditionsRequests addObject:request];
        }
        [self.application endBackgroundTask:backgroundTask];
    }
}

- (void)didBecameActive {
    [self retryWaitingConditions];
}

- (void)didEnterBackground {
    [self retryWaitingConditions];

    NSArray *copy;
    @synchronized (self.retryingRequests) {
        copy = [self.retryingRequests copy];
        [self.retryingRequests removeAllObjects];
    }

    for (UATaskRequest *request in copy) {
        [self attemptRequest:request nextBackOff:30];
    }
}

- (void)retryWaitingConditions {
    NSArray *copy;
    @synchronized (self.waitingConditionsRequests) {
        copy = [self.waitingConditionsRequests copy];
        [self.waitingConditionsRequests removeAllObjects];
    }

    for (UATaskRequest *request in copy) {
        [self attemptRequest:request nextBackOff:kUATaskManagerInitialBackOff];
    }
}

- (BOOL)checkRequestRequirements:(UATaskRequest *)request {
    __block NSTimeInterval remainingTime = 0;
    [[UADispatcher mainDispatcher] doSync:^{
        remainingTime = self.application.backgroundTimeRemaining;
    }];

    if (remainingTime < kUATaskManagerMinBackgroundTime) {
        return NO;
    }

    if (@available(ios 12.0, tvOS 12.0, *)) {
        if (request.options.isNetworkRequired && !self.networkMonitor.isConnected) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isRequestCurrent:(UATaskRequest *)request {
    @synchronized (self.currentRequests) {
        return [self.currentRequests[request.taskID] containsObject:request];
    }
}

- (void)requestFinished:(UATaskRequest *)request {
    @synchronized (self.currentRequests) {
        [self.currentRequests[request.taskID] removeObject:request];
    }
}

+ (NSTimeInterval)nextBackOff:(NSTimeInterval)backOff {
    return MIN(backOff * 2, kUATaskManagerMaxBackOff);
}

@end
