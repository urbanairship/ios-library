/* Copyright Airship and Contributors */

#import "UAirshipCoreResources.h"

@implementation UAirshipCoreResources

+ (NSBundle *)bundle {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Airship_AirshipCore"
                                                                                ofType:@"bundle"]];

    return bundle ? : [NSBundle bundleForClass:[self class]];
}

@end
