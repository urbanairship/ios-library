//
//  AirshipLib - UABaseLocationDelegateTest.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UABaseLocationDelegate.h"
#import "UAStandardLocationDelegate.h"
#import "UASignificantChangeDelegate.h"
#import "UALocationServicesCommon.h"
#import <SenTestingKit/SenTestingKit.h>

/** testing all the delegates in one class because
 *  they are all small. If this changes, break them out 
 *  to there own files
 */

@interface UALocationDelegateTests : SenTestCase

@end


@implementation UALocationDelegateTests

- (void)testInitWithDelegate {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    UABaseLocationDelegate *base = [[UABaseLocationDelegate alloc] initWithDelegate:mockDelegate];
    STAssertNotNil(base, nil);
    STAssertEquals(base.provider, kUALocationServiceProviderUNKNOWN, @"base.provider should be UNKNOWN");
    STAssertEqualObjects(mockDelegate, base.delegate, nil);
    [base release];
}

//TODO: add accuracy calculations here. 

- (void)testStandardInitWithDelegate {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    UAStandardLocationDelegate *delegate = [UAStandardLocationDelegate locationDelegateWithServiceDelegate:mockDelegate];
    STAssertNotNil(delegate, nil);
    STAssertEquals(delegate.provider, kUALocationServiceProviderGPS, @"provider should be GPS");
    STAssertEqualObjects(mockDelegate, delegate.delegate, nil);
}

- (void)testSignificantChangeInitWithDelegate {
    id mockDelegate = [OCMockObject mockForProtocol:@protocol(UALocationServiceDelegate)];
    UASignificantChangeDelegate *delegate = [UASignificantChangeDelegate locationDelegateWithServiceDelegate:mockDelegate];
    STAssertNotNil(delegate, nil);
    STAssertEquals(delegate.provider, kUALocationServiceProviderNETWORK, @"provider should be NETWORK");
    STAssertEqualObjects(mockDelegate, delegate.delegate, nil);
}

@end
