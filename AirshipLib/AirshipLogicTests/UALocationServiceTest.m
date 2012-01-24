//
//  AirshipLib - UALocationManagerTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UALocationService.h"
#import "UALocationServicesCommon.h"
#import "UALocationService_Private.h"
#import "UAStandardLocationDelegate.h"
#import "UASignificantChangeDelegate.h"
#import "JRSwizzle.h"
#import <SenTestingKit/SenTestingKit.h>

@interface UALocationServiceTest : SenTestCase
{
    UALocationService *locationService;
}
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
@end


@implementation UALocationServiceTest

- (void)setUp {
    locationService = [[UALocationService alloc] init];
}

- (void)tearDown {
    [locationService autorelease];
    locationService = nil;
}

- (void)testInit
{
    STAssertEquals(locationService.standardLocationServiceStatus, UALocationServiceNotUpdating, @"location service should not be updating");
    STAssertEquals(locationService.significantChangeServiceStatus, UALocationServiceNotUpdating, @"locaiton service should not be updating");
    CLLocationManager *test = [[CLLocationManager alloc] init];
    STAssertEquals(locationService.desiredAccuracy, test.desiredAccuracy, @"Default CLManger values should match UALocationService defaults");
    STAssertEquals(locationService.distanceFilter, test.distanceFilter, @"Default CLManger values should match UALocationService defaults");
    [test autorelease];
}

- (void)testStandardLocationSetter {
    id mockLocationService = [OCMockObject partialMockForObject:locationService];
    id mockDelegate = [OCMockObject mockForClass:[UAStandardLocationDelegate class]];
    [[mockLocationService expect] setDistanceFilterAndDesiredLocation:mockDelegate];
    [[mockDelegate expect] setDelegate:locationService];
    [locationService setStandardLocationDelegate:mockDelegate];
    [mockDelegate verify];
    // Use a nice mock so no errors are thrown when mehtods are called
    // just check that the previous object has been released
    id secondDelegate = [OCMockObject niceMockForClass:[UAStandardLocationDelegate class]];
    [[mockLocationService expect] setDistanceFilterAndDesiredLocation:secondDelegate];
    [locationService setDistanceFilterAndDesiredLocation:secondDelegate];
    [mockLocationService verify];
    STAssertTrue([mockDelegate isEqual:mockDelegate], @"Mock objects should be equal");
    STAssertFalse([mockDelegate isEqual:secondDelegate], @"These two objects should not be equal");
}

- (void)testSignificantChangeSetter {
    id mockLocationService = [OCMockObject partialMockForObject:locationService];
    id mockDelegate = [OCMockObject mockForClass:[UASignificantChangeDelegate class]];
    [[mockLocationService expect] setDistanceFilterAndDesiredLocation:mockDelegate];
    [[mockDelegate expect] setDelegate:locationService];
    [locationService setStandardLocationDelegate:mockDelegate];
    [mockDelegate verify];
    // Use a nice mock so no errors are thrown when mehtods are called
    // just check that the previous object has been released
    id secondDelegate = [OCMockObject niceMockForClass:[UASignificantChangeDelegate class]];
    [[mockLocationService expect] setDistanceFilterAndDesiredLocation:secondDelegate];
    [locationService setDistanceFilterAndDesiredLocation:secondDelegate];
    [mockLocationService verify];
    STAssertFalse([mockDelegate isEqual:secondDelegate], @"These two objects should not be equal");
}

- (void)testSetDistanceFilterAndDesiredLocation {
    UABaseLocationDelegate *delegate = [[UABaseLocationDelegate alloc] init];
    // Set the desiredAccuracy && distanceFilter to values other than the default
    CLLocationAccuracy five = 5.0;
    CLLocationDistance six = 6.0;
    delegate.locationManager.desiredAccuracy = five;
    delegate.locationManager.distanceFilter = six;
    [locationService setDistanceFilterAndDesiredLocation:delegate];
    STAssertEquals(locationService.distanceFilter, delegate.locationManager.distanceFilter, nil);
    STAssertEquals(locationService.desiredAccuracy, delegate.locationManager.desiredAccuracy, nil);
}

- (void)testStartUpdatingLocation {
    id mockService = [OCMockObject partialMockForObject:locationService];
    UAStandardLocationDelegate *standardDelegate = [[UAStandardLocationDelegate alloc] initWithDelegate:locationService];
    locationService.standardLocationDelegate = standardDelegate;
    id mockDelegate = [OCMockObject partialMockForObject:standardDelegate];
    [[[mockService expect] andForwardToRealObject] startUpdatingLocation];
    BOOL yes = YES;
    [[[mockService expect] andReturnValue:OCMOCK_VALUE(yes)] checkAuthorizationAndAvailabiltyOfLocationServices];
    [locationService startUpdatingLocation];
    [mockService verify];
    [mockDelegate verify];
    [standardDelegate autorelease];
}

#pragma mark -
#pragma Support Methods

// Don't forget to unswizzle the swizzles in cases of strange behavior
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector {
    NSError *swizzleError = nil;
    [CLLocationManager jr_swizzleClassMethod:oneSelector withClassMethod:anotherSelector error:&swizzleError];
    STAssertNil(swizzleError, @"Method swizzling for CLLocationManager failed with error %@", swizzleError.description);
}

- (void)swizzleCLLocationClassEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;
    [self swizzleCLLocationClassMethod:@selector(locationServicesEnabled) withMethod:@selector(returnYES)];
    [self swizzleCLLocationClassMethod:@selector(authorizationStatus) withMethod:@selector(returnCLLocationStatusAuthorized)];    
    STAssertNil(locationServicesSizzleError, @"Error swizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error swizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
}

- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized {
    NSError *locationServicesSizzleError = nil;
    NSError *authorizationStatusSwizzleError = nil;
    [self swizzleCLLocationClassMethod:@selector(returnCLLocationStatusAuthorized) withMethod:@selector(authorizationStatus)];
    [self swizzleCLLocationClassMethod:@selector(returnYES) withMethod:@selector(locationServicesEnabled)];
    STAssertNil(locationServicesSizzleError, @"Error unsizzling locationServicesCall on CLLocation error %@", locationServicesSizzleError.description);
    STAssertNil(authorizationStatusSwizzleError, @"Error unswizzling authorizationStatus on CLLocation error %@", authorizationStatusSwizzleError.description);
}


@end
