//
//  UALocationService.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationService.h"
#import "UALocationService_Private.h"
#import "UABaseLocationDelegate.h"
#import "UAGlobal.h"
#import "UALocationUtils.h"
#import "UAStandardLocationDelegate.h"
#import "UASignificantChangeDelegate.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UAEvent.h"

@implementation UALocationService

@synthesize standardLocationDelegate = standardLocationDelegate_;
@synthesize standardLocationServiceStatus = standardLocationServiceStatus_;
@synthesize significantChangeDelegate = significantChangeDelegate_;
@synthesize significantChangeServiceStatus = significantChangeServiceStatus_;
@synthesize distanceFilter = distanceFilter_;
@synthesize desiredAccuracy = desiredAccuracy_;

static UAStandardLocationDelegate *singleLocationDelegate = nil;

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    RELEASE_SAFELY(standardLocationDelegate_);
    RELEASE_SAFELY(significantChangeDelegate_);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if(self){
        // Default CLManagerValues
        desiredAccuracy_ = kCLLocationAccuracyBest;
        distanceFilter_ = kCLDistanceFilterNone;
        standardLocationServiceStatus_ = UALocationServiceNotUpdating;
        significantChangeServiceStatus_ = UALocationServiceNotUpdating;
    }
    return self;
}

#pragma mark -
#pragma mark UACLLocationMangerDelegate

- (void)uaLocationDelgate:(id<UALocationDelegateProtocol>)locationDelegate 
      withLocationManager:(CLLocationManager*)locationManager 
         didFailWithError:(NSError*)error {
    //TODO: notifiy something, somewhere, to maybe do a thing
}


- (void)uaLocationDelegate:(id<UALocationDelegateProtocol>)locationDelegate
       withLocationManager:(CLLocationManager *)locationManager 
         didUpdateLocation:(CLLocation*)location {
    [self sendLocationToAnalytics:location fromProvider:locationDelegate.provider withManager:locationManager];
    if (locationDelegate == singleLocationDelegate) {
        [singleLocationDelegate.locationManager stopUpdatingLocation];
        @synchronized (self){
            [singleLocationDelegate release];
            singleLocationDelegate = nil;
        }
    }
}

#pragma mark -
#pragma mark UALocationService

- (void)setStandardLocationDelegate:(UAStandardLocationDelegate *)standardLocationDelegate {
    [standardLocationDelegate_ autorelease];
    standardLocationDelegate_ = [standardLocationDelegate retain];
    standardLocationDelegate_.delegate = self;
    [self setDistanceFilterAndDesiredLocation:standardLocationDelegate_];
}

- (void)setSignificantChangeDelegate:(UASignificantChangeDelegate *)significantChangeDelegate {
    [significantChangeDelegate_ autorelease];
    significantChangeDelegate_ = [significantChangeDelegate retain];
    significantChangeDelegate_.delegate = self;
    [self setDistanceFilterAndDesiredLocation:significantChangeDelegate];
}

- (void)setDistanceFilterAndDesiredLocation:(UABaseLocationDelegate*)locationDelegate {
    if (distanceFilter_) {
        locationDelegate.locationManager.distanceFilter = distanceFilter_;
    }
    if (desiredAccuracy_) {
        locationDelegate.locationManager.desiredAccuracy = desiredAccuracy_;
    }
}

#pragma mark -
#pragma mark CLLocationManager Methods

// Lazy load delegate objects

- (void)startUpdatingLocation {
    if ([self checkAuthorizationAndAvailabiltyOfLocationServices]) {
        if (!standardLocationDelegate_)
            self.standardLocationDelegate = [UAStandardLocationDelegate locationDelegateWithServiceDelegate:self];
        [standardLocationDelegate_.locationManager startUpdatingLocation];
        self.standardLocationServiceStatus = UALocationServiceUpdating;
    }
}

- (void)stopUpdatingLocation {
    [standardLocationDelegate_.locationManager stopUpdatingLocation];
    self.standardLocationServiceStatus = UALocationServiceNotUpdating;
    RELEASE_SAFELY(standardLocationDelegate_);
}

- (void)startMonitoringSignificantLocationChanges {
    if([self checkAuthorizationAndAvailabiltyOfLocationServices]){
        if(!significantChangeDelegate_)
            self.significantChangeDelegate = [UASignificantChangeDelegate locationDelegateWithServiceDelegate:self];
        self.significantChangeServiceStatus = UALocationServiceUpdating;
    }
}

- (void)stopMonitoringSignificantLocationChanges {
    [significantChangeDelegate_.locationManager stopUpdatingLocation];
    self.significantChangeServiceStatus = UALocationServiceNotUpdating;
    RELEASE_SAFELY(significantChangeDelegate_);
}

#pragma mark -
#pragma mark UALocationEvent Analytics

- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationValues:(CLLocation*)location {
    [dictionary setValue:[UALocationUtils stringFromDouble:location.coordinate.latitude] forKey:kLatKey];
    [dictionary setValue:[UALocationUtils stringFromDouble:location.coordinate.longitude] forKey:kLongKey];
    [dictionary setValue:[UALocationUtils stringFromDouble:location.horizontalAccuracy] forKey:kHorizontalAccuracyKey];
    [dictionary setValue:[UALocationUtils stringFromDouble:location.verticalAccuracy] forKey:kVerticalAccuracyKey];
}

- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationManagerValues:(CLLocationManager*)manager {
    [dictionary setValue:[UALocationUtils stringFromDouble:[manager desiredAccuracy]] forKey:kDesiredAccuracyKey]; 
    [dictionary setValue:[UALocationUtils stringFromDouble:[manager distanceFilter]] forKey:kUpdateDistanceKey];
}

- (void)sendLocationToAnalytics:(CLLocation*)location fromProvider:(NSString *)provider withManager:(CLLocationManager*)manager {
    if(!provider) provider = kUALocationServiceProviderUNKNOWN;
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:7];
    [dictionary setValue:provider forKey:kProviderKey];
    [self populateDictionary:dictionary withLocationValues:location];
    [self populateDictionary:dictionary withLocationManagerValues:manager];
    UAAnalytics *analytics = [UAirship shared].analytics;
    UALocationEvent *locationEvent = [UALocationEvent eventWithContext:dictionary];
    [analytics addEvent:locationEvent];
}

#pragma mark -
#pragma mark CLLocationManager Authorization for Location Services

- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices {
    if (![CLLocationManager locationServicesEnabled]) return NO;
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorized) return NO;
    return YES;
}

#pragma mark -
#pragma mark Single Location Service

//TODO: set this up as a background task
- (void)acquireSingleLocationAndUpload {
    if ([self checkAuthorizationAndAvailabiltyOfLocationServices]) {
        singleLocationDelegate = [[UAStandardLocationDelegate alloc] initWithDelegate:self];
        [singleLocationDelegate.locationManager startUpdatingLocation];
    }    
}





@end

