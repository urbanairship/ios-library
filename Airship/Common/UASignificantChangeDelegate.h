//
//  UASignificantChangeDelegate.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UABaseLocationDelegate.h"

@interface UASignificantChangeDelegate : UABaseLocationDelegate

- (BOOL)locationMeetsAccuracyRequirements:(CLLocation *)location;
+ (UASignificantChangeDelegate*)locationDelegateWithServiceDelegate:(id<UALocationServiceDelegate>)delegateOrNil;

@end
