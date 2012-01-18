//
//  UALocationAnalyticsProtocol.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/18/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/** Create an event with the following parameters
 *
 *  Both UALocationManger and CLLocationManager meet this
 *  requirement allowing the same methods to be used for both
 **/

#import <CoreLocation/CoreLocation.h>

@protocol UALocationAnalyticsProtocol <NSObject>
@required
- (CLLocationAccuracy)desiredAccuracy;
- (CLLocationDistance)distanceFilter;
@end
