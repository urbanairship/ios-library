//
//  UACLLocationManagerDelegate.m
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UABaseLocationDelegate.h"
#import "UAGlobal.h"
#import "UAEvent.h"
#import "UALocationUtils.h"
#import "UAirship.h"
#import "UAAnalytics.h"

@implementation UABaseLocationDelegate

@synthesize locationManager = locationManager_;
@synthesize serviceStatus = serviceStatus;
@synthesize delegate = delegate_;
@synthesize provider = provider_;

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    RELEASE_SAFELY(locationManager_);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self){
        locationManager_ = [[CLLocationManager alloc] init];
        locationManager_.delegate = self;
        provider_ = kUALocationServiceProviderUNKNOWN;
    }
    return self;
}

- (id)initWithDelegate:(id<UALocationServiceDelegate>) delegate {
    self = [self init];
    if (self && [delegate conformsToProtocol:@protocol(UALocationServiceDelegate)]) {
        delegate_ = delegate;
    }
    return self;
}
                                                            

#pragma mark -
#pragma mark Location Accuracy calculations

//TODO: solve accuracy calculation issues
- (BOOL)locationMeetsAccuracyRequirements:(CLLocation*)location {
    if(location.horizontalAccuracy < locationManager_.desiredAccuracy) return YES;
    return NO;
}

#pragma mark -
#pragma mark CLLocationManger Delegate

/** iOS 4.2 or better */
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {

}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if ([self locationMeetsAccuracyRequirements:newLocation]) {

    }
}






@end
