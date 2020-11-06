/* Copyright Airship and Contributors */

#import "UAExpirableTask+Internal.h"
#import "UAGlobal.h"

@interface UAExpirableTask()
@property(nonatomic, copy) NSString *taskID;
@property(nonatomic, copy) void (^completionHandler)(BOOL);
@property(nonatomic, strong) UATaskRequestOptions *requestOptions;
@property(assign) BOOL isExpired;
@property(assign) BOOL isCompleted;
@end

@implementation UAExpirableTask

@synthesize expirationHandler = _expirationHandler;
@synthesize taskID;

- (instancetype)initWithTaskID:(NSString *)taskID
                       options:(UATaskRequestOptions *)requestOptions
             completionHandler:(void (^)(BOOL))completionHandler {
    self = [super init];
    if (self) {
        self.taskID = taskID;
        self.requestOptions = requestOptions;
        self.completionHandler = completionHandler;
    }
    return self;
}

+ (instancetype)taskWithID:(NSString *)taskID
                   options:(UATaskRequestOptions *)requestOptions
         completionHandler:(void (^)(BOOL))completionHandler {
    return [[self alloc] initWithTaskID:taskID options:requestOptions completionHandler:completionHandler];
}

- (void)taskCompleted {
    @synchronized (self) {
        if (self.isCompleted) {
            return;
        }
        _expirationHandler = nil;
        self.isCompleted = YES;
        self.completionHandler(YES);
    }
}

- (void)taskFailed {
    @synchronized (self) {
        if (self.isCompleted) {
            return;
        }
        _expirationHandler = nil;
        self.isCompleted = YES;
        self.completionHandler(NO);
    }
}

- (void)expire {
    @synchronized (self) {
        if (self.isCompleted) {
            return;
        }

        self.isExpired = YES;
        if (self.expirationHandler) {
            self.expirationHandler();
            _expirationHandler = nil;
        } else {
            UA_LDEBUG(@"Expiration handler not set, marking task as failed.");
            [self taskFailed];
        }
    }
}

- (void)setExpirationHandler:(void (^)(void))expirationHandler {
    @synchronized (self) {
        if (self.isExpired) {
            if (expirationHandler) {
                expirationHandler();
            }
            return;
        }

        _expirationHandler = expirationHandler;
    }
}

@end

