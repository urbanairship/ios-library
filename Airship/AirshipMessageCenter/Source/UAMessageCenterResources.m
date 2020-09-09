/* Copyright Airship and Contributors */

#import "UAMessageCenterResources.h"

@implementation UAMessageCenterResources

+ (NSBundle *)bundle {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"Airship_AirshipMessageCenter"
                                                                                ofType:@"bundle"]];

    return bundle ? : [NSBundle bundleForClass:[self class]];
}

@end
