/* Copyright Airship and Contributors */

#import "UATaskLauncher+Internal.h"
#import "UAGlobal.h"

@interface UATaskLauncher()
@property(nonatomic, strong) UADispatcher *dispatcher;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

@implementation UATaskLauncher

- (instancetype)initWithDispatcher:(nullable UADispatcher *)dispatcher
                     launchHandler:(void (^)(id<UATask>))launchHandler {
    self = [super init];
    if (self) {
        self.dispatcher = dispatcher ?: [UADispatcher globalDispatcher];
        self.launchHandler = launchHandler;
    }
    return self;
}

+ (instancetype)launcherWithDispatcher:(nullable UADispatcher *)dispatcher
                         launchHandler:(void (^)(id<UATask>))launchHandler {
    return [[self alloc] initWithDispatcher:dispatcher launchHandler:launchHandler];
}

- (void)launch:(id<UATask>)task {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        self.launchHandler(task);
    }];
}

@end
