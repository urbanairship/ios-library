/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageButtonView+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"

@interface UAInAppMessageButtonView ()
@property(nonatomic, strong) NSArray<UAInAppMessageButtonInfo *> *buttons;
@property(nonatomic, strong) NSString *buttonLayout;
@end

@implementation UAInAppMessageButtonView

+ (instancetype)buttonViewWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons layout:(NSString *)layout {
    return [[UAInAppMessageButtonView alloc] initWithButtons:buttons layout:layout];
}

- (instancetype)initWithButtons:(NSArray<UAInAppMessageButtonInfo *> *)buttons layout:(NSString *)layout {
    self = [super init];

    if (self) {
        self.buttons = buttons;
        self.buttonLayout = layout;
    }

    return self;
}

@end
