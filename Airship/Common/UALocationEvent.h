/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <CoreLocation/CoreLocation.h>
#import "UAEvent.h"
#import "UALocationProviderProtocol.h"

/** Keys and values for location analytics */
typedef NSString UALocationEventAnalyticsKey;
extern UALocationEventAnalyticsKey * const uaLocationEventSessionIDKey; 
extern UALocationEventAnalyticsKey * const uaLocationEventForegroundKey; 
extern UALocationEventAnalyticsKey * const uaLocationEventLatitudeKey;
extern UALocationEventAnalyticsKey * const uaLocationEventLongitudeKey;
extern UALocationEventAnalyticsKey * const uaLocationEventDesiredAccuracyKey;
extern UALocationEventAnalyticsKey * const uaLocationEventUpdateTypeKey;
extern UALocationEventAnalyticsKey * const uaLocationEventProviderKey;
extern UALocationEventAnalyticsKey * const uaLocationEventDistanceFilterKey;
extern UALocationEventAnalyticsKey * const uaLocationEventHorizontalAccuracyKey;
extern UALocationEventAnalyticsKey * const uaLocationEventVerticalAccuracyKey;

typedef NSString UALocationEventUpdateType;
extern UALocationEventUpdateType * const uaLocationEventAnalyticsType;
extern UALocationEventUpdateType * const uaLocationEventUpdateTypeChange;
extern UALocationEventUpdateType * const uaLocationEventUpdateTypeContinuous;
extern UALocationEventUpdateType * const uaLocationEventUpdateTypeSingle;
extern UALocationEventUpdateType * const uaLocationEventUpdatetypeNone;


/** A UALocationEvent captures all the necessary information for 
 UAAnalytics
 */

@interface UALocationEvent : UAEvent


///---------------------------------------------------------------------------------------
/// @name Object Creation
///---------------------------------------------------------------------------------------

/** Create a UALocationEvent
 @param context A dictionary populated with all required data
 @return A UALocationEvent populated with appropriate values
 */
- (id)initWithLocationContext:(NSDictionary*)context;

/** Creates a UALocationEvent parsing the necessary data from the method parameters
 @param location Location going to UAAnalytics
 @param provider Provider that produced the location
 @param updateType One of the UALocationEvent updated types, see header for more details
 @return UALocationEvent populated with the necessary values
 */
- (id)initWithLocation:(CLLocation*)location 
              provider:(id<UALocationProviderProtocol>)provider 
         andUpdateType:(UALocationEventUpdateType*)updateType; 

/** Creates a UALocationEvent parsing the necessary data form the method parameters.
 @param location Location going to UAAnalytics
 @param locationManager The location manager that produced the location
 @param updateType One of the UALocationEvent updated types, see header for more details
 @return UALocationEvent populated with the necessary values
 */
 
- (id)initWithLocation:(CLLocation*)location 
       locationManager:(CLLocationManager*)locationManager 
         andUpdateType:(UALocationEventUpdateType*)updateType;

+ (UALocationEvent*)locationEventWithLocation:(CLLocation*)location 
                                     provider:(id<UALocationProviderProtocol>)provider 
                                andUpdateType:(UALocationEventUpdateType*)updateType;

+ (UALocationEvent*)locationEventWithLocation:(CLLocation*)loction 
                              locationManager:(CLLocationManager*)locationManager 
                                andUpdateType:(UALocationEventUpdateType*)updateType;


///---------------------------------------------------------------------------------------
/// @name Support Methods
///---------------------------------------------------------------------------------------

/** Creates a dictionary with the appropriate data gather from the location and locationManager
 */
- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationValues:(CLLocation*)location;
- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationManagerValues:(CLLocationManager*)locationManager;
- (void)populateDictionary:(NSMutableDictionary*)dictionary withLocationProviderValues:(id<UALocationProviderProtocol>)locationProvider;



/** Converts a double to a string keeping seven digit of precision 
 Seven digits produces sub meter accuracy at the equator.
 http://en.wikipedia.org/wiki/Decimal_degrees
 @param doubleValue The double to convert.
 @return Returns an NSString representing the 7 digit value
 */
- (NSString*)stringFromDoubleToSevenDigits:(double)doubleValue;




@end