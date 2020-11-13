/* Copyright Airship and Contributors */

#import "UATaskRequestOptions.h"

@interface UATaskRequestOptions()
@property(nonatomic, assign) UATaskConflictPolicy conflictPolicy;
@property(nonatomic, assign) BOOL isNetworkRequired;
@property(nonatomic, copy, nullable) NSDictionary *extras;
@end

@implementation UATaskRequestOptions

- (instancetype)initWithConflictPolicy:(UATaskConflictPolicy)conflictPolicy
                       requiresNetwork:(BOOL)requiresNetwork
                                extras:(nullable NSDictionary *)extras {
    self = [super init];
    if (self) {
        self.conflictPolicy = conflictPolicy;
        self.isNetworkRequired = requiresNetwork;
        self.extras = extras;
    }
    return self;
}

+ (instancetype)defaultOptions {
    static dispatch_once_t defaultOptionsOnceToken;
    static UATaskRequestOptions *defaultOptions;
    dispatch_once(&defaultOptionsOnceToken, ^{
        defaultOptions = [[self alloc] initWithConflictPolicy:UATaskConflictPolicyReplace requiresNetwork:YES extras:nil];
    });

    return defaultOptions;
}

+ (instancetype)optionsWithConflictPolicy:(UATaskConflictPolicy)conflictPolicy
                          requiresNetwork:(BOOL)requiresNetwork
                                   extras:(nullable NSDictionary *)extras {
    return [[self alloc] initWithConflictPolicy:conflictPolicy requiresNetwork:requiresNetwork extras:extras];
}
@end
