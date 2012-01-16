//
//  UASingleLocationAcquireAndUpload_Private.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/16/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/*  Private Methods
 *  This header should be imported into the implementation
 *  file and the test file
 \*/

@interface UASingleLocationAcquireAndUpload ()
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, assign) UALocationManagerServiceActivityStatus serviceStatus;
- (BOOL)locationMeetsAccuracyRequirements:(CLLocation*)location;
- (void)sendLocationToAnalytics:(CLLocation*)location;
@end

