//
//  UALocationServices.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//


@class UALocationServiceManager;
@interface UALocationServices : NSObject

+ (BOOL)acquireSingleLocationAndUpload;
+ (UALocationServiceManager*)managerWithStandardService;
+ (UALocationServiceManager*)managerWithSignificantChangeService;
@end
