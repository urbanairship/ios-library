/* Copyright Airship and Contributors */

#import "UAExtendedActionsResources.h"

@implementation UAExtendedActionsResources

+ (NSBundle *)bundle {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *sourceBundle = [NSBundle bundleForClass:[self class]];

    // SPM
    NSBundle *bundle = [NSBundle bundleWithPath:[mainBundle pathForResource:@"Airship_AirshipExtendedActions"
                                                                     ofType:@"bundle"]];
    // Cocopaods (static)
    bundle = bundle ? : [NSBundle bundleWithPath:[mainBundle pathForResource:@"AirshipExtendedActionsResources"
                                                                      ofType:@"bundle"]];
    // Cocopaods (framework)
    bundle = bundle ? : [NSBundle bundleWithPath:[sourceBundle pathForResource:@"AirshipExtendedActionsResources"
                                                                        ofType:@"bundle"]];
    return bundle ? : sourceBundle;
}

@end
