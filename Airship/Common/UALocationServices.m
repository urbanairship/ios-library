//
//  UALocationServices.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationServices.h"

@implementation UALocationServices

static UALocationServiceManager* singleLocationManager = nil;

+ (BOOL) acquireSingleLocationAndUpload {
    return NO;
}
+ (UALocationServiceManager*)managerWithStandardService {
    return nil;
}
+ (UALocationServiceManager*)managerWithSignificantChangeService{
    return nil;
}

@end
