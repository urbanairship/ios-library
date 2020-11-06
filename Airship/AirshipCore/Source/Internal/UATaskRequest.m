/* Copyright Airship and Contributors */

#import "UATaskRequest+Internal.h"

@interface UATaskRequest()
@property(nonatomic, copy) NSString *taskID;
@property(nonatomic, strong) UATaskRequestOptions *options;
@property(nonatomic, strong) UATaskLauncher *launcher;
@end

@implementation UATaskRequest

- (instancetype)initWithID:(NSString *)taskID
                   options:(UATaskRequestOptions *)options
                  launcher:(UATaskLauncher *)launcher {
    self = [super init];
    if (self) {
        self.taskID = taskID;
        self.options = options;
        self.launcher = launcher;
    }
    return self;
}


+ (instancetype)requestWithID:(nonnull NSString *)taskID
                      options:(UATaskRequestOptions *)options
                     launcher:(nonnull UATaskLauncher *)launcher {

    return [[self alloc] initWithID:taskID
                            options:options
                           launcher:launcher];
}

@end
