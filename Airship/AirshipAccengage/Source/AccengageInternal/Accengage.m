/* Copyright Airship and Contributors */

#import "Accengage.h"

@implementation Accengage

+ (ACCUserProfile *)profile {
    static ACCUserProfile *sharedUserProfile = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedUserProfile = [[ACCUserProfile alloc] init];
    });
    return sharedUserProfile;
}

@end
