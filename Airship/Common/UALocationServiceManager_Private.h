//
//  UALocationServiceaManager_Private.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/22/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationServiceManager.h"

@interface UALocationServiceManager () {

}
@property (nonatomic, retain) id <UALocationService> locationService;
@property (nonatomic, assign) id <UALocationServiceDelegate> delegate;
@property (nonatomic, assign) UALocationServiceStatus serviceStatus;
@property (nonatomic, retain) CLLocation *lastReportedLocation;
@property (nonatomic, retain) NSDate *lastLocationAttempt;
- (void)startObservingUIApplicationStateNotifications;
- (void)stopObservingUIApplicationStateNotifications;
- (void)receivedUIApplicationDidEnterBackgroundNotification;
- (void)receivedUIApplicationWillEnterForegroundNotification;
@end
