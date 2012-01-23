//
//  UAStandardLocationDelegate.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UAStandardLocationDelegate.h"
#import "UALocationServicesCommon.h"

@implementation UAStandardLocationDelegate

- (id)init {
    self = [super init];
    if (self){
        provider_ = kUALocationServiceProviderGPS;
    }
    return self;
}

+ (UAStandardLocationDelegate*)locationDelegateWithServiceDelegate:(id<UALocationServiceDelegate>)serviceDelegateOrNil {
    return [[[UAStandardLocationDelegate alloc] initWithDelegate:serviceDelegateOrNil] autorelease];
}
@end
