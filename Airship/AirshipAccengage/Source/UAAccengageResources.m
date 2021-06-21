/* Copyright Airship and Contributors */

#import "UAAccengageResources.h"

@implementation UAAccengageResources

+ (NSBundle *)bundle {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *sourceBundle = [NSBundle bundleForClass:[self class]];

    // SPM
    NSBundle *bundle = [NSBundle bundleWithPath:[mainBundle pathForResource:@"Airship_AirshipAccengage"
                                                                     ofType:@"bundle"]];
    // Cocopaods (static)
    bundle = bundle ? : [NSBundle bundleWithPath:[mainBundle pathForResource:@"AirshipAccengageResources"
                                                                      ofType:@"bundle"]];
    // Cocopaods (framework)
    bundle = bundle ? : [NSBundle bundleWithPath:[sourceBundle pathForResource:@"AirshipAccengageResources"
                                                                        ofType:@"bundle"]];
    return bundle ? : sourceBundle;
}

@end
