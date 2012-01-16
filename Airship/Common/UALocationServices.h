//
//  UALocationServices.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/* Common variables for the UALocationServices classes */

#import <CoreLocation/CoreLocation.h>
#import "UAEvent.h"

#define kSessionIdKey @"session_id"
#define kLatKey @"lat"
#define kLongKey @"long"
#define kRequestedAccuracyKey @"requested_accuracy"
#define kUpdateTypeKey @"update_type"
#define kProviderKey @"provider"
#define kUpdateDistanceKey @"update_dist"
#define kHorizontalAccuracyKey @"h_accuracy"
#define kVerticalAccuracyKey @"v_accuracy"
#define kForegroundKey @"foreground"

typedef enum {
    UALocationServiceNotUpdating = 0,
    UALocationServiceUpdating
} UALocationManagerServiceActivityStatus;

@interface UALocationServices : NSObject 

/** Returns an event populated with the correct
 *  information for UAnalytics
 */
+ (UAEvent*)createEventWithLocation:(CLLocation*)location;
@end