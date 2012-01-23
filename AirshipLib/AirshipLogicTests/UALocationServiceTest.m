//
//  AirshipLib - UALocationServiceTest.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

    // Class under test
#import "UALocationService.h"
#import "UALocationService_Private.h"
#import <SenTestingKit/SenTestingKit.h>


@interface UALocationServiceTest : SenTestCase {
    UALocationService *service_;
}
@property (nonatomic, retain) UALocationService *service;
@end


@implementation UALocationServiceTest
@synthesize service = service_;

- (void)setUp {
    self.service = [[UALocationService alloc] init];
}

- (void)tearDown {
    [service_ release];
}

- (void)testExample
{
    STAssertNotNil(service_ , nil);
}

@end
