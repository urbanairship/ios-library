/* Copyright 2018 Urban Airship and Contributors */

#import "UAInAppMessageResolution.h"

@interface UAInAppMessageResolution()
@property (nonatomic, strong, nullable) UAInAppMessageButtonInfo *buttonInfo;
@property (nonatomic, assign) UAInAppMessageResolutionType type;
@end

@implementation UAInAppMessageResolution

- (instancetype)initWithType:(UAInAppMessageResolutionType)type
                  buttonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    self = [super init];

    if (self) {
        self.type = type;
        self.buttonInfo = buttonInfo;
    }

    return self;
}

+ (instancetype)buttonClickResolutionWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeButtonClick
                           buttonInfo:buttonInfo];
}


+ (instancetype)messageClickResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeMessageClick
                           buttonInfo:nil];
}


+ (instancetype)userDismissedResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeUserDismissed
                           buttonInfo:nil];
}

+ (instancetype)timedOutResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeTimedOut
                           buttonInfo:nil];
}

@end

