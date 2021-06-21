/* Copyright Airship and Contributors */

#import "UAAutomationResources.h"

@implementation UAAutomationResources

+ (NSBundle *)bundle {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *sourceBundle = [NSBundle bundleForClass:[self class]];

    // SPM
    NSBundle *bundle = [NSBundle bundleWithPath:[mainBundle pathForResource:@"Airship_AirshipAutomation"
                                                                     ofType:@"bundle"]];
    // Cocopaods (static)
    bundle = bundle ? : [NSBundle bundleWithPath:[mainBundle pathForResource:@"AirshipAutomationResources"
                                                                      ofType:@"bundle"]];
    // Cocopaods (framework)
    bundle = bundle ? : [NSBundle bundleWithPath:[sourceBundle pathForResource:@"AirshipAutomationResources"
                                                                        ofType:@"bundle"]];
    return bundle ? : sourceBundle;
}

@end
