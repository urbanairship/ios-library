//
//  UALocationServices.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/* Common variables for the UALocationServices classes */

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesCommon.h"


@interface NSString (LocationUtils)
+ (NSString*)stringFromDouble:(double)doubleValue;
@end

@class UALocationManager;
@class UAEvent;
@interface UALocationUtils : NSObject 

/** Returns an event populated with the correct
 *  information for UAnalytics
 */
+ (UAEvent*)createEventWithLocation:(CLLocation*)location forManager:(id<UALocationAnalyticsProtocol>)manager;
/** Returns a dictionary populates with values parsed from a CLLocation
 *  object. The double values in the CLLocation (Core Location Constants) are
 *  converted to strings. 
 **/
+ (void)populateDictionary:(NSDictionary*)dictionary withLocationValues:(CLLocation*)location;
/** Returns a dictionary populated with values parsed from the UALocationManager
 *  The double values in the UALocationManager object are converted to strings
 **/
+ (void)populateDictionary:(NSDictionary*)dictionary withLocationManagerValues:()manager;
@end