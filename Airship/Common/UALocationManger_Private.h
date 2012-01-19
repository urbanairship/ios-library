//
//  UALocationManger_Private.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/18/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//
#import "UASingleLocationAcquireAndUpload.h"


@interface UALocationManager () {
    UASingleLocationAcquireAndUpload *singleLocationUpload_;
}

- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices;
- (void)startObservingUIApplicationStateNotifications;
- (void)stopObservingUIApplicationStateNotifications;
- (BOOL)testAccuracyOfLocation:(CLLocation*)newLocation;
- (void)updateLastLocation:(CLLocation*)newLocation;
- (void)stopAllLocationUpdates;
- (void)receivedUIApplicationDidEnterBackgroundNotification;
- (void)receivedUIApplicationWillEnterForegroundNotification;
- (void)createAndScheduleLocationUpdateTimer;
- (void)invalidateAndReleaseUpdateTimer;

@property (nonatomic, assign) UALocationManagerServiceActivityStatus standardLocationActivityStatus;
@property (nonatomic, assign) UALocationManagerServiceActivityStatus significantChangeActivityStatus;
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@property (nonatomic, retain) NSTimer *locationUpdateTimer;
@property (nonatomic, retain) NSDate *dateOfLastLocationUpdateAttempt;
@property (nonatomic, assign) id <UALocationServicesDelegate> delegate;
@property (nonatomic, retain) UASingleLocationAcquireAndUpload *singleLocationUpload;
@property (nonatomic, assign) BOOL automaticStandardLocationUpdatesEnabled;
@end
