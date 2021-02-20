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

- (BOOL)isEqualToTaskRequestOptions:(UATaskRequestOptions *)options {
    return self.conflictPolicy == options.conflictPolicy
    && self.isNetworkRequired == options.isNetworkRequired
    && [self.extras isEqualToDictionary:options.extras];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UATaskRequestOptions class]]) {
        return NO;
    }

    return [self isEqualToTaskRequestOptions:object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.extras hash];
    result = 31 * result + self.conflictPolicy;
    result = 31 * result + self.isNetworkRequired;

    return result;
}

@end
