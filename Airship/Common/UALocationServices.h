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