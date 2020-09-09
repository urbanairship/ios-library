/* Copyright Airship and Contributors */

#import "UAAccengageResources.h"

@implementation UAAccengageResources

+ (NSBundle *)bundle {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Airship_AirshipAccengage"
                                                                                ofType:@"bundle"]];

    return bundle ? : [NSBundle bundleForClass:[self class]];
}

@end
