//
//  AirshipLib - UASingleLocationAcquireAndUploadTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "JRSwizzle.h"
#import "UAGlobal.h"
#import "UASingleLocationAcquireAndUpload.h"
#import "UASingleLocationAcquireAndUpload_Private.h"
#import "CLLocationManager+Test.h"

@interface UASingleLocationAcquireAndUpload (Test) 
- (void)setLocationManager:(CLLocationManager*)locationManager;
@end

@implementation UASingleLocationAcquireAndUpload (Test) 
- (void) setLocationManager:(CLLocationManager*)locationManager {
    [locationManager_ release];
    locationManager_ = [locationManager retain];
    locationManager_.delegate = self;
}
@end


@interface UASingleLocationAcquireAndUploadTests : SenTestCase {
    UASingleLocationAcquireAndUpload *testUploader_;
    CLLocation *testLocationOne_;
    CLLocation *testLocationTwo_;
    CLLocationDistance testDistance_; 
    CLLocationAccuracy testAccuracy_;
}
- (void)setUpTestDistanceAndAccuracy;
- (void)setUpTestLocations;
- (void)tearDownTestLocations;
// Swizzling
- (void)swizzleCLLocationClassMethod:(SEL)oneSelector withMethod:(SEL)anotherSelector;
- (void)swizzleCLLocationClassEnabledAndAuthorized;
- (void)swizzleCLLocationClassBackFromEnabledAndAuthorized;
@end


@implementation UASingleLocationAcquireAndUploadTests

- (void)setUp {
    testUploader_ = [[UASingleLocationAcquireAndUpload alloc] initWithDelegate:nil];
    STAssertNotNil(testUploader_, @"testUploader_ should not be nil");
}

- (void)tearDown {
    [testUploader_ release];
    testUploader_ = nil;
}

#pragma -
#pragma On demand setup methods
- (void)setUpTestDistanceAndAccuracy {
    testDistance_ = 100.0;
    // CLLocationAccuracy best is the default, don't use that
    testAccuracy_ = kCLLocationAccuracyHundredMeters;
}

- (void)setUpTestLocations {
    CLLocationCoordinate2D coord1 = CLLocationCoordinate2DMake(45.525352839897, -122.682115697712);
    CLLocationCoordinate2D coord2 = CLLocationCoordinate2DMake(37.7726834626323, -122.406178648848);
    testLocationOne_ = [[CLLocation alloc] initWithCoordinate:coord1 altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    testLocationTwo_ = [[CLLocation alloc] initWithCoordinate:coord2 altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 timestamp:[NSDate date]];
    STAssertNotNil(testLocationOne_, @"location allocation fail");
    STAssertNotNil(testLocationTwo_, @"location allocaiton fail");
}

- (void)tearDownTestLocations {
    [testLocationOne_ release];
    testLocationOne_ = nil; 
    [testLocationTwo_ release];
}
// Only testing get/set methods since they are being forwarded and retrieved from a different object
- (void)testGetSetMethodsForLocationManager {
    [self setUpTestDistanceAndAccuracy];
    // Check the distance from the CLLocationManager directly
    testUploader_.desiredAccuracy = testAccuracy_;
    testUploader_.distanceFilter = testDistance_;
    //Test the CLLocationManager directly
    NSString *distanceFilterTag = @"distanceFilterForStandardLocation";
    NSString *desiredAccuracyTag = @"desiredAccuracyForStandardLocation";
    STAssertEquals(testDistance_, testUploader_.locationManager.distanceFilter, @"%@ setter broken", distanceFilterTag);
    STAssertEquals(testDistance_, testUploader_.distanceFilter, @"%@ getter broken", distanceFilterTag);
    STAssertEquals(testAccuracy_, testUploader_.locationManager.desiredAccuracy, @"%@ setter broken", desiredAccuracyTag);
    STAssertEquals(testAccuracy_, testUploader_.desiredAccuracy, @"%@ getter broken", desiredAccuracyTag);
}

- (void)testAcquireAndSendWhenAuthorized {
    [self swizzleCLLocationClassEnabledAndAuthorized];
    id mockLocationManger = [OCMockObject niceMockForClass:[CLLocationManager class]];
    testUploader_.locationManager = mockLocationManger;
    [[mockLocationManger expect] startUpdatingLocation];
    [testUploader_ acquireAndSendLocationToUA];
    [mockLocationManger verify];
    [self swizzleCLLocationClassBackFromEnabledAndAuthorized];
}

- (void)testLocationMeetsAccuracyRequirements {
    testUploader_.desiredAccuracy = 10.0;
    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(45.00, 45.0) altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:0.0 timestamp:[NSDate date]];
    BOOL accuracyTest = [testUploader_ locationMeetsAccuracyRequirements:testLocation];
    STAssertEquals(YES, accuracyTest, @"accuracyTest should be YES");
    [testLocation release];
    testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(45.0, 45.0) altitude:100.0 horizontalAccuracy:25.0 verticalAccuracy:0.0 timestamp:[NSDate date]];
    accuracyTest = [testUploader_ locationMeetsAccuracyRequirements:testLocation];
    STAssertEquals(NO, accuracyTest, @"accuracyTest should be NO");
}

- (void)testShutdownAfterAcceptableLocationIsReturned {
    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(45.0, 45.0) altitude:100.0 horizontalAccuracy:5.0 verticalAccuracy:0.0 timestamp:[NSDate date]];
    testUploader_.desiredAccuracy = 10.0;
    id mockLocationManager = [OCMockObject partialMockForObject:testUploader_.locationManager];
    [[[mockLocationManager stub] andForwardToRealObject] stopUpdatingLocation];
    [testUploader_.locationManager sendDidUpdateToLocation:testLocation fromLocation:nil];
    [mockLocationManager verify];
    STAssertEquals(UALocationServiceNotUpdating, testUploader_.serviceStatus, @"serviceStatus should be UALocationServiceNotUpdating");
    [testLocation release];
}

//- (void)testLocationIsSentToUAAnalytics {
//    CLLocation *testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(45.0, 45.0) altitude:10.0 horizontalAccuracy:5.0 verticalAccuracy:5.0 course:90.0 speed:69.0 timestamp:[NSDate date]];
//    [UALocationServices createEventWithLocation:testLocation];
//    [testLocation release];
//}

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
