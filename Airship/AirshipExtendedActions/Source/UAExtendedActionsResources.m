/* Copyright Airship and Contributors */

#import "UAExtendedActionsResources.h"

@implementation UAExtendedActionsResources

+ (NSBundle *)bundle {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Airship_AirshipAutomation"
                                                                                ofType:@"bundle"]];

    return bundle ? : [NSBundle bundleForClass:[self class]];
}

@end
