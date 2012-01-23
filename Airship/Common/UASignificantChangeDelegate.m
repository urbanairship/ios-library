//
//  UASignificantChangeDelegate.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UASignificantChangeDelegate.h"

@implementation UASignificantChangeDelegate

- (id)init {
    self = [super init];
    if (self) {
        provider_ = kUALocationServiceProviderNETWORK;
    }
    return self;
}

- (BOOL)locationMeetsAccuracyRequirements:(CLLocation *)location {
    return YES;
}

+ (UASignificantChangeDelegate*)locationDelegateWithServiceDelegate:(id<UALocationServiceDelegate>)delegateOrNil {
    return [[[UASignificantChangeDelegate alloc] initWithDelegate:delegateOrNil] autorelease];
}
@end
