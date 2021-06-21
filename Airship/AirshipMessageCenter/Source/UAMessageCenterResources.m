/* Copyright Airship and Contributors */

#import "UAMessageCenterResources.h"

@implementation UAMessageCenterResources

+ (NSBundle *)bundle {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *sourceBundle = [NSBundle bundleForClass:[self class]];

    // SPM
    NSBundle *bundle = [NSBundle bundleWithPath:[mainBundle pathForResource:@"Airship_AirshipMessageCenter"
                                                                     ofType:@"bundle"]];
    // Cocopaods (static)
    bundle = bundle ? : [NSBundle bundleWithPath:[mainBundle pathForResource:@"AirshipMessageCenterResources"
                                                                      ofType:@"bundle"]];
    // Cocopaods (framework)
    bundle = bundle ? : [NSBundle bundleWithPath:[sourceBundle pathForResource:@"AirshipMessageCenterResources"
                                                                        ofType:@"bundle"]];
    return bundle ? : sourceBundle;
}

@end
