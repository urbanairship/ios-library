//
//  UAStandardLocationDelegate.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//
#import "UABaseLocationDelegate.h"

@interface UAStandardLocationDelegate : UABaseLocationDelegate
+ (UAStandardLocationDelegate*)locationDelegateWithServiceDelegate:(id<UALocationServiceDelegate>)serviceDelegateOrNil;
@end
