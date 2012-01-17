//
//  UALocationServices.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/13/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

/* Common variables for the UALocationServices classes */

#import "UALocationServices.h"
#import "UAirship.h" // temp
#import "UAAnalytics.h" // temp


@implementation NSString (LocationUtils)

// TODO: look into optimizing this to avoid the NSNumber throwaway object
+ (NSString*)stringFromDouble:(double)doubleValue {
    NSNumber *number = [NSNumber numberWithDouble:doubleValue];
    return [number stringValue];
}

@end


@implementation UALocationServices

/**
 
 "session_id": "UUID"
 "lat" : "31.3847" (required, DDD.dddd... string double)
 "long": "32.3847" (required, DDD.dddd... string double)
 "requested_accuracy": "10.0,100.0,NONE" (required, requested accuracy in meters as a string double)
 "update_type": "CHANGE, CONTINUOUS, SINGLE, NONE" (required - string enum)
 "provider": "GPS, NETWORK, PASSIVE, UNKNOWN" (required - string enum)
 "update_dist": "10.0,100.0,NONE" (required - string double distance in meters, or NONE if not available/applicable)
 "h_accuracy": "10.0, NONE" (required, string double - actual horizontal accuracy in meters, or NONE if not available)
 "v_accuracy": "10.0, NONE" (required, string double - actual vertical accuracy in meters, or NONE if not available)
 "foreground": "true" (required, string boolean)
 **/

+ (UAEvent*)createEventWithLocation:(CLLocation*)location forManager:(UALocationManager*)manager {
    [location retain];    
    [manager retain];
    NSMutableDictionary *eventData = [NSMutableDictionary dictionaryWithCapacity:10];
    [UALocationServices populateDictionary:eventData withLocationValues:location];
    [UALocationServices populateDictionary:eventData withLocationManagerValues:manager];
    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    // Set app state and session id
    if (UIApplicationStateActive == appState) {
        [eventData setValue:@"true" forKey:kForegroundKey];
        NSDictionary* session = [UAirship shared].analytics.session;
        [eventData setValue:[session valueForKey:@"session"] forKey:kSessionIdKey];
    }
    else {
        [eventData setValue:@"false" forKey:kForegroundKey];
        [eventData setValue:@"" forKey:kSessionIdKey];
    }
    ////////
    UAEvent* event = [UALocationEvent eventWithContext:eventData];
    // cleanup memory
    [location release];
    [manager release];
    return event;
}

+ (void)populateDictionary:(NSDictionary*)dictionary withLocationValues:(CLLocation*)location {
    [dictionary setValue:[NSString stringFromDouble:location.coordinate.latitude] forKey:kLatKey];
    [dictionary setValue:[NSString stringFromDouble:location.coordinate.longitude] forKey:kLongKey];
    [dictionary setValue:[NSString stringFromDouble:location.horizontalAccuracy] forKey:kHorizontalAccuracyKey];
    [dictionary setValue:[NSString stringFromDouble:location.verticalAccuracy] forKey:kVerticalAccuracyKey];
}

+ (void)populateDictionary:(NSDictionary*)dictionary withLocationManagerValues:(UALocationManager*)manager {
    [dictionary setValue:[NSString stringFromDouble:manager.locationManager.desiredAccuracy] forKey:kDesiredAccuracyKey]; 
    [dictionary setValue:[NSString stringFromDouble:manager.locationManager.distanceFilter] forKey:kUpdateDistanceKey];
}
                                  
                                  

@end