//
//  UALocationService.h
//  AirshipLib
//
//  Created by Matt Hooge on 1/23/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "UALocationServicesCommon.h"

@class UAStandardLocationDelegate;
@class UASignificantChangeDelegate;

@interface UALocationService : NSObject <UALocationServiceDelegate> {
    UAStandardLocationDelegate *standardLocationDelegate_;
    UALocationServiceStatus standardLocationServiceStatus_;
    UASignificantChangeDelegate *significantChangeDelegate_;
    UALocationServiceStatus significantChangeServiceStatus_;
    CLLocationDistance distanceFilter_;
    CLLocationAccuracy desiredAccuracy_;
}
@property (nonatomic, retain, readonly) UAStandardLocationDelegate *standardLocationDelegate;
@property (nonatomic, assign, readonly) UALocationServiceStatus standardLocationServiceStatus;
@property (nonatomic, retain, readonly) UASignificantChangeDelegate *significantChangeDelegate;
@property (nonatomic, assign, readonly) UALocationServiceStatus significantChangeServiceStatus;
@property (nonatomic, assign) CLLocationDistance distanceFilter;
@property (nonatomic, assign) CLLocationAccuracy desiredAccuracy;

/** All location services check for authorization through [CLLocationManager locationServiceEnabled]
 *  and [CLLocationManager authorizationStatus] (if available). If any result other than kCLAuthorizationStatusAuthorized
 *  is returned, location updates will not start
 */

/** Starts the Standard Location service and 
 *  sends location data to Urban Airship. This service
 *  will continue updating if the location property is
 *  declared in the Info.plist. Please see the Location Awareness Programming guide:
 *  http://developer.apple.com/library/ios/#documentation/UserExperience/Conceptual/LocationAwarenessPG/Introduction/Introduction.html
 *  for more information. If the standard location service is not setup for background
 *  use, it will automatically resume once the app is brought back into the foreground.
 */
- (void)startUpdatingLocation;

/** Stops the standard location service */
- (void)stopUpdatingLocation;

/** Starts the Significant Change location service
 *  and sends location data to Urban Airship. This service 
 *  will continue in the background if stopMonitoringSignificantLocationChanges
 *  is not called before the app enters the background.
 **/
- (void)startMonitoringSignificantLocationChanges;

/** Stops the Significant Change location service */
- (void)stopMonitoringSignificantLocationChanges;

/** Creates a UALocationEvent and enques it 
 *  Requires a CLLocation object and a string
 *  representing a service provider which is one of the 
 *  following:
 *  kUALocationServiceProviderGPS  
 *  kUALocationServiceProviderNETWORK 
 *  kUALocationServiceProviderREGION 
 *  If nothing is provided, the default value of
 *  kUALocationServiceProviderUNKNOWN
 *  will be used
 */
- (void)sendLocationToAnalytics:(CLLocation*)location fromProvider:(NSString *)provider withManager:(CLLocationManager*)manager;

/** Populate an dictionary with pertinent information about the location. Uses tags described in 
 *  UALocationServices.h
 */
- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationValues:(CLLocation*)location;

/** Populate a dictionary with pertinent information about a location manager. Used tags described in 
 *  UALocationServices.h
 */
- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationManagerValues:(CLLocationManager*)manager;

/** Checks both locationServicesEnabled and authorizationStatus
 *  for CLLocationManager an records state of appropriate flags.
 *  Returns:
 *      YES if locationServicesAreEnabled and kCLAuthorizationStatusAuthorized
 *      NO in all other cases
 */
- (BOOL)checkAuthorizationAndAvailabiltyOfLocationServices;

/** Starts the standard location service, acquires a single location, sends
 *  it to Urban Airship, then shuts down the service. 
 */
- (void)acquireSingleLocationAndUpload;



@end
