/* Copyright Airship and Contributors */

#import "UATaskLauncher+Internal.h"
#import "UAGlobal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif


@interface UATaskLauncher()
@property(nonatomic, strong) UADispatcher *dispatcher;
@property(nonatomic, copy) void (^launchHandler)(id<UATask>);
@end

@implementation UATaskLauncher

- (instancetype)initWithDispatcher:(nullable UADispatcher *)dispatcher
                     launchHandler:(void (^)(id<UATask>))launchHandler {
    self = [super init];
    if (self) {
        self.dispatcher = dispatcher ?: UADispatcher.global;
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
