/* Copyright Airship and Contributors */

#import "UAirshipCoreResources.h"

@implementation UAirshipCoreResources

+ (NSBundle *)bundle {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *sourceBundle = [NSBundle bundleForClass:[self class]];

    // SPM
    NSBundle *bundle = [NSBundle bundleWithPath:[mainBundle pathForResource:@"Airship_AirshipCore"
                                                                     ofType:@"bundle"]];
    // Cocopaods (static)
    bundle = bundle ? : [NSBundle bundleWithPath:[mainBundle pathForResource:@"AirshipCoreResources"
                                                                      ofType:@"bundle"]];
    // Cocopaods (framework)
    bundle = bundle ? : [NSBundle bundleWithPath:[sourceBundle pathForResource:@"AirshipCoreResources"
                                                                        ofType:@"bundle"]];
    return bundle ? : sourceBundle;
}

@end
