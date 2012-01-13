//
//  UASingleLocationAcquireAndUplaod.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UASingleLocationAcquireAndUpload.h"
#import "UAGlobal.h"

@interface UASingleLocationAcquireAndUpload ()
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, assign) UALocationManagerServiceActivityStatus serviceStatus;
- (BOOL)locationMeetsAccuracyRequirements:(CLLocation*)location;
- (void)sendLocationToAnalytics:(CLLocation*)location;
@end

@implementation UASingleLocationAcquireAndUpload

@synthesize locationManager = locationManager_;
@synthesize serviceStatus = serviceStatus_;
@synthesize delegate = delegate_;

#pragma mark -
#pragma Life Cycle management
- (void)dealloc {
    RELEASE_SAFELY(locationManager_);
    [super dealloc];
}

- (id)initWithDelegate:(id<UALocationServicesDelegate>)delegateOrNil {
    self = [super init];
    if(self){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        delegate_ = delegateOrNil;
        serviceStatus_ = UALocationServiceNotUpdating;
    }
    return self;
}

#pragma mark -
#pragma CLLocationManager property accessors

- (CLLocationAccuracy)desiredAccuracy {
    return locationManager_.desiredAccuracy;
}

- (void)setDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    locationManager_.desiredAccuracy = desiredAccuracy;
}

- (CLLocationDistance)distanceFilter {
    return locationManager_.distanceFilter;
}

- (void)setDistanceFilter:(CLLocationDistance)distanceFilter {  
    locationManager_.distanceFilter = distanceFilter;
}


#pragma mark -
#pragma CLLocationManager delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if ([self locationMeetsAccuracyRequirements:newLocation]) {
        [locationManager_ stopUpdatingLocation];  
        serviceStatus_ = UALocationServiceNotUpdating;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (delegate_ && [delegate_ conformsToProtocol:@protocol(UALocationServicesDelegate)]) {
        if([delegate_ respondsToSelector:@selector(uaLocationManager:locationManager:didFailWithError:)]){
            [delegate_ uaLocationManager:self locationManager:manager didFailWithError:error];
        }
    }
}

#pragma mark -
#pragma Accuracy algorithm

- (BOOL)locationMeetsAccuracyRequirements:(CLLocation*)location {
    // Stop trying to get a location if accuracy is not improved
    //
    return NO;
}
#pragma mark -
#pragma UAAnalytics

// TODO: notify delegate if analytics send fail occurred
- (void)sendLocationToAnalytics:(CLLocation*)location {
    
}

#pragma mark -
#pragma UASingleLocationAcquireAndUpload

- (BOOL)acquireAndSendLocationToUA {
    BOOL enabled = [CLLocationManager locationServicesEnabled];
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (kCLAuthorizationStatusAuthorized == status && YES == enabled) {
        [locationManager_ startUpdatingLocation];
        serviceStatus_ = UALocationServiceUpdating;
        return YES;
    }
    return NO;
}
@end
