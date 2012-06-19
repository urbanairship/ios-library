//
//  PushSampleLib - UAirshipTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <SenTestingKit/SenTestingKit.h>
#import "UAirship.h"
#import "UALocationService.h"

@interface UAirshipTests : SenTestCase
@end

@implementation UAirshipTests

// Testing because of lazy instantiation
- (void)testLocationGetSet {
    UAirship *airship = [UAirship shared];
    UALocationService *location = airship.locationService ;
    STAssertTrue([location isKindOfClass:[UALocationService class]],nil);
}
@end
