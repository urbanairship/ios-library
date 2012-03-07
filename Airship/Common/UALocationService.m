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

#import "UALocationServicesCommon.h"
#import "UALocationService.h"
#import "UALocationService_Private.h"
#import "UABaseLocationProvider.h"
#import "UAGlobal.h"
#import "UALocationUtils.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UAAnalytics.h"
#import "UAirship.h"
#import "UALocationEvent.h"

//#define kAnalyticsTrue @"true"
//#define kAnalyticsFalse @"false"

#pragma mark -
#pragma mark NSUserPreferences keys for location service persistence
static NSString* const standardLocationServiceRestartKey = @"standardLocationServiceStatusRestart";
static NSString* const significantChangeServiceRestartKey = @"significantChangeServiceStatusRestart";

@implementation UALocationService

#pragma mark -
#pragma mark UALocationService.h
@synthesize minimumTimeBetweenForegroundUpdates = minimumTimeBetweenForegroundUpdates_;
@synthesize distanceFilter = distanceFilter_;
@synthesize desiredAccuracy = desiredAccuracy_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize dateOfLastReport = dateOfLastReport_;
@synthesize delegate = delegate_;
@synthesize automaticLocationOnForegroundEnabled = automaticLocationOnForegroundEnabled_;
@synthesize backgroundLocationServiceEnabled = backroundLocationServiceEnabled_;
@synthesize standardLocationProvider = standardLocationProvider_;
@synthesize significantChangeProvider = significantChangeProvider_;

#pragma mark -
#pragma mark UALocationService_Private.h
@synthesize locationServiceValues = locationServiceValues_;
@synthesize singleLocationProvider = singleLocationProvider_;
@synthesize deprecatedLocation = deprecatedLocation_;

#pragma mark -
#pragma mark UALocationServicePreferences in locationServiceValues
// These are stored in NSUserDefaults
@synthesize locationServiceAllowed;
@synthesize purpose = purpose_;
@synthesize locationServiceEnabled;


#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    [self endObservingLocationSettings];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // private
    RELEASE_SAFELY(locationServiceValues_);
    RELEASE_SAFELY(standardLocationProvider_);
    RELEASE_SAFELY(significantChangeProvider_);
    RELEASE_SAFELY(singleLocationProvider_);
    //
    // public
    RELEASE_SAFELY(lastReportedLocation_);
    RELEASE_SAFELY(dateOfLastReport_);
    //
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        // Default CLManagerValues
        // TODO: set these values to something more appropriate
        minimumTimeBetweenForegroundUpdates_ = 120.0;
        desiredAccuracy_ = kCLLocationAccuracyBest;
        distanceFilter_ = kCLDistanceFilterNone;
        // Read existing values and create a mutable object
        NSDictionary* currentPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:UALocationServicePreferences];
        locationServiceValues_ = [[NSMutableDictionary alloc] initWithDictionary:currentPrefs];
        [self beginObservingLocationSettings];
        [self refreshLocationServiceAuthorization];
        [self beginObservingUIApplicationState];
        standardLocationProvider_ = [[UAStandardLocationProvider alloc] initWithDelegate:self];
    }
    return self;
}

- (id)initWithPurpose:(NSString*)purpose {
    self = [self init];
    if(self){
        if (purpose){
            purpose_ = [purpose copy];
            standardLocationProvider_.purpose = purpose;
        }
    }
    return self;
}

#pragma mark -
#pragma mark Application State Change Management

- (void)beginObservingUIApplicationState {
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(appWillEnterForeground) 
                                                 name:UIApplicationWillEnterForegroundNotification 
                                               object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(appDidEnterBackground) 
                                                 name:UIApplicationDidEnterBackgroundNotification 
                                               object:[UIApplication sharedApplication]];
}

- (void)appWillEnterForeground {
    if ([self shouldPerformAutoLocationUpdate]) {
        [self reportCurrentLocation];
    }
    // If the location services were not allowed in the background, and they were tracking when the app entered the background
    // restart them now. 
    if(!backroundLocationServiceEnabled_){
        BOOL startStandard = [[locationServiceValues_ valueForKey:standardLocationServiceRestartKey] boolValue];
        BOOL startSignificantChange = [[locationServiceValues_ valueForKey:significantChangeServiceRestartKey] boolValue];
        if (startStandard)[self startReportingLocation];
        if (startSignificantChange)[self startReportingSignificantLocationChanges];
    }
}

- (BOOL)shouldPerformAutoLocationUpdate {
    // if not enabled, bail
    if (!automaticLocationOnForegroundEnabled_) return NO; 
    // If the date is nil, then a report is needed
    if (!dateOfLastReport_) return YES;
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:dateOfLastReport_];
    if(elapsedTime < minimumTimeBetweenForegroundUpdates_) {
        return NO;
    }
    return YES;
}

- (void)appDidEnterBackground {
    if (!backroundLocationServiceEnabled_) {
        if (standardLocationProvider_.serviceStatus == UALocationProviderUpdating) {
            [self setBool:YES forLocationServiceKey:standardLocationServiceRestartKey];
        }
        else {
            [self setBool:NO forLocationServiceKey:standardLocationServiceRestartKey];
        }
        if (significantChangeProvider_.serviceStatus == UALocationProviderUpdating){
            [self setBool:YES forLocationServiceKey:significantChangeServiceRestartKey];
        }
        else {
            [self setBool:NO forLocationServiceKey:significantChangeServiceRestartKey];
        }
        [self stopReportingLocation];
        [self stopReportingSignificantLocationChanges];
    }
}

#pragma mark -
#pragma mark UALocationProviderStatus

- (UALocationProviderStatus) standardLocationServiceStatus {
    return standardLocationProvider_.serviceStatus;
}

- (UALocationProviderStatus) significantChangeServiceStatus {
    return significantChangeProvider_.serviceStatus;
}

- (UALocationProviderStatus) singleLocationServiceStatus {
    return singleLocationProvider_.serviceStatus;
}


#pragma mark -
#pragma mark UALocationService NSUserDefaults

#pragma mark UALocationServiceValues Get/Set
- (BOOL)locationServiceEnabled {
    return [[locationServiceValues_ valueForKey:UALocationServiceEnabledKey] boolValue];
}

- (BOOL)locationServiceAllowed {
    return [[locationServiceValues_ valueForKey:UALocationServiceAllowedKey] boolValue];
}

- (NSString*)purpose {
    return [locationServiceValues_ valueForKey:UALocationServicePurposeKey];
}

// Setting these values will trigger a NSUserDefaults update with a KVO notification
- (void)setLocationServiceEnabled:(BOOL)UALocationServiceEnabled_ {
    [self setBool:UALocationServiceEnabled_ forLocationServiceKey:UALocationServiceEnabledKey];
}

- (void)setLocationServiceAllowed:(BOOL)UALocationServiceAllowed_ {
    [self setBool:UALocationServiceAllowed_ forLocationServiceKey:UALocationServiceAllowedKey];
}

- (void)setPurpose:(NSString *)purpose {
    // purpose gets a retain before being entered in the dictionary, and copy has a +1 count
    // at creation.
    [locationServiceValues_ setValue:[[purpose copy] autorelease] forKey:UALocationServicePurposeKey];
}
//
#pragma mark NSUserDefaults Get/Set
// Setting these values will trigger a NSUserDefaults update with a KVO notification

- (void)setValue:(id)value forLocationServiceKey:(NSString*)key {
    [locationServiceValues_ setValue:value forKey:key];
}

- (void)setBool:(BOOL)boolValue forLocationServiceKey:(NSString*)key {
    [self setValue:[NSNumber numberWithBool:boolValue] forLocationServiceKey:key];
}

- (id)valueForLocationServiceKey:(NSString*)key {
    return [locationServiceValues_ valueForKey:key];
}

- (BOOL)boolForLocationServiceKey:(NSString*)key {
    return [[locationServiceValues_ valueForKey:key] boolValue];
}

#pragma mark kUALocationServicePreferences NSUserDefaults Key Value Observation

- (void)beginObservingLocationSettings {
    [locationServiceValues_ addObserver:self forKeyPath:UALocationServiceEnabledKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:@"allowed"];
    [locationServiceValues_ addObserver:self forKeyPath:UALocationServiceAllowedKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:@"enabled"];
    [locationServiceValues_ addObserver:self forKeyPath:UALocationServicePurposeKey options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) context:@"purpose"];
}

- (void)endObservingLocationSettings {
    [locationServiceValues_ removeObserver:self forKeyPath:UALocationServiceEnabledKey];
    [locationServiceValues_ removeObserver:self forKeyPath:UALocationServiceAllowedKey];
    [locationServiceValues_ removeObserver:self forKeyPath:UALocationServicePurposeKey];
}

#pragma mark KVO Callback
// Compares the two values from the KVO callback, and only updates the preferences if they have changed
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    id old = [change valueForKey:NSKeyValueChangeOldKey];
    id new = [change valueForKey:NSKeyValueChangeNewKey];
    // NSObject defines isEqual, and it's overidden by NSString and NSNumber
    if([old isEqual:new])return;
    [[NSUserDefaults standardUserDefaults] setObject:locationServiceValues_ forKey:UALocationServicePreferences];
    
}


#pragma mark -
#pragma mark UALocationServiceAllowed authorization methods
// This method encapsulates the logic for iOS < 4.2 
- (void)refreshLocationServiceAuthorization {
    // If this is less than iOS 4.2, UALocationPreferences defaults to NO, 
    // and will be reset to NO on any kCLErrorDenied delegate callback from 
    // CLLocationManger.
    if(deprecatedLocation_) return;
    self.locationServiceAllowed = [self isLocationServiceEnabledAndAuthorized];
}


#pragma mark -
#pragma mark UALocationProviderDelegate Methods

- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider 
       withLocationManager:(CLLocationManager*)locationManager 
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    [self updateAllowedStatus:status];
    if(!locationServiceEnabled){
        [locationProvider stopReportingLocation];
    }
    if ([delegate_ respondsToSelector:@selector(UALocationService:didChangeAuthorizationStatus:)]) {
        [delegate_ UALocationService:self didChangeAuthorizationStatus:status];
    }
}


- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider 
       withLocationManager:(CLLocationManager*)locationManager 
          didFailWithError:(NSError*)error {
    // Catch kCLErrorDenied for iOS < 4.2
    if (error.code == kCLErrorDenied) {
        [locationProvider stopReportingLocation];
        if(deprecatedLocation_){
            self.locationServiceAllowed = NO;
        }
        else {
            [self updateAllowedStatus:kCLAuthorizationStatusDenied];
        }            
    }
    if([delegate_ respondsToSelector:@selector(UALocationService:didFailWithError:)]) {
        [delegate_ UALocationService:self didFailWithError:error];
    }
}

- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider
       withLocationManager:(CLLocationManager *)locationManager 
         didUpdateLocation:(CLLocation*)newLocation
              fromLocation:(CLLocation*)oldLocation {
    [self sendLocationToAnalytics:newLocation fromProvider:locationProvider];
    self.lastReportedLocation = newLocation; 
    self.dateOfLastReport = [NSDate date];
    // Single location auto shutdown
    if (locationProvider == singleLocationProvider_) {
        [singleLocationProvider_ stopReportingLocation];
        RELEASE_SAFELY(singleLocationProvider_);
        return;
    }
    BOOL isActive = ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive);
    if (isActive && [delegate_ respondsToSelector:@selector(UALocationService:didUpdateToLocation:fromLocation:)]) {
        [delegate_ UALocationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark UALocationService Status Support Methods

- (void)updateAllowedStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusNotDetermined) {
        self.locationServiceAllowed = YES;
        return;
    }
    self.locationServiceAllowed = NO;
}

#pragma mark -
#pragma mark UALocationProvider/CLLocationManager service controls

#pragma mark Standard Location
- (void)startReportingLocation {
    if(!standardLocationProvider_){
        self.standardLocationProvider = [[[UAStandardLocationProvider alloc] init] autorelease];
    }
    if(self.locationServiceAllowed && self.locationServiceEnabled) {
        [standardLocationProvider_ startReportingLocation];
        return;
    }
    // TODO: Make delegate error call with custom Error states for not authorized or not enabled
}

// Keep the standardLocationProvider around for the life of the object to receive didChangeAuthorization 
// callbacks 
- (void)stopReportingLocation {
    [standardLocationProvider_ stopReportingLocation];
}

#pragma mark Significant Change
- (void)startReportingSignificantLocationChanges {
    if(!significantChangeProvider_){
        self.significantChangeProvider = [[[UASignificantChangeProvider alloc] init] autorelease];
    }
    if(self.locationServiceAllowed && self.locationServiceEnabled) {
        [significantChangeProvider_ startReportingLocation];
        return;
    }
    // TODO: Make delegate error call with custom Error states for not authorized or not enabled
}

// Release the significantChangeProvider to prevent double delegate callbacks
// when authorization state changes
- (void)stopReportingSignificantLocationChanges {
    [significantChangeProvider_ stopReportingLocation];
    RELEASE_SAFELY(significantChangeProvider_);
}


#pragma mark -
#pragma mark UALocationService Setters
//
// releases the previous LocationProvider and retains the new one
// sets the delegate of the provider to self
//
- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider {
    [standardLocationProvider_ autorelease];
    standardLocationProvider_ = [standardLocationProvider retain];
    [self setCommonPropertiesOnProvider:standardLocationProvider_];
}

- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider {
    [significantChangeProvider_ autorelease];
    significantChangeProvider_ = [significantChangeProvider retain];
    [self setCommonPropertiesOnProvider:significantChangeProvider_];
}

- (void)setSingleLocationProvider:(UAStandardLocationProvider *)singleLocationProvider {
    [singleLocationProvider_ autorelease];
    singleLocationProvider_ = [singleLocationProvider retain];
    singleLocationProvider_.purpose = self.purpose;
    [self setCommonPropertiesOnProvider:singleLocationProvider_];
}

- (void)setCommonPropertiesOnProvider:(UABaseLocationProvider*)locationProvider {
    if (distanceFilter_) {
        locationProvider.locationManager.distanceFilter = distanceFilter_;
    }
    if (desiredAccuracy_) {
        locationProvider.locationManager.desiredAccuracy = desiredAccuracy_;
    }
    locationProvider.delegate = self;
    locationProvider.purpose = self.purpose;
}


#pragma mark -
#pragma mark UALocationEvent Analytics

- (void)sendLocationToAnalytics:(CLLocation *)location fromProvider:(id<UALocationProviderProtocol>)provider {
    UALocationEvent *event = [self createLocationEventWithLocation:location andProvider:provider];
    if (provider == standardLocationProvider_) {
        [event addDataWithValue:UALocationEventUpdateTypeCONTINUOUS forKey:UALocationEventUpdateTypeKey];
    }
    if (provider == significantChangeProvider_) {
        [event addDataWithValue:UALocationEventUpdateTypeCHANGE forKey:UALocationEventUpdateTypeKey];
    }
    if (provider == singleLocationProvider_) {
        [event addDataWithValue:UALocationEventUpdateTypeSINGLE forKey:UALocationEventUpdateTypeKey];
    }
    [[UAirship shared].analytics addEvent:event];
}


#pragma mark -
#pragma mark CLLocationManager Authorization for Location Services

// Ignore the depricated method call for ivar locationServiceEnabled. There is a dynamic
// check for the existence of the method before calling. 
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (BOOL)isLocationServiceEnabledAndAuthorized {
    if (deprecatedLocation_) {
        BOOL depricatedEnabled = NO;
        if ([standardLocationProvider_.locationManager respondsToSelector:@selector(locationServicesEnabled)]) {
            depricatedEnabled = standardLocationProvider_.locationManager.locationServicesEnabled;
        }
        return (depricatedEnabled && self.locationServiceAllowed);
    }
    BOOL enabled = [CLLocationManager locationServicesEnabled];
    CLAuthorizationStatus authorization = [CLLocationManager authorizationStatus];
    // User hasn't been asked
    if (enabled && authorization == kCLAuthorizationStatusNotDetermined) {
        return YES;
    }
    // User has explicilty enabled service
    if (enabled && authorization == kCLAuthorizationStatusAuthorized) {
        return YES;
    }
    return NO;
}
#pragma GCC diagnostic warning "-Wdeprecated-declarations"

#pragma mark -
#pragma mark Single Location Service

- (void)reportCurrentLocation {
    if(singleLocationProvider_.serviceStatus == UALocationProviderUpdating) return;    
    if (!singleLocationProvider_) {
        self.singleLocationProvider = [UAStandardLocationProvider  providerWithDelegate:self];
    }
    if(self.locationServiceAllowed && self.locationServiceEnabled){
        [singleLocationProvider_ startReportingLocation];
    }
}

//The context includes all the data necessary for a 
//location event. These are:
//
//"lat" : "31.3847" (required, DDD.dddd... string double)
//"long": "32.3847" (required, DDD.dddd... string double)
//"requested_accuracy": "10.0,100.0,NONE" (required, requested accuracy in meters as a string double)
//"update_type": "CHANGE, CONTINUOUS, SINGLE, NONE" (required - string enum)
//"provider": "GPS, NETWORK, PASSIVE, UNKNOWN" (required - string enum)
//"update_dist": "10.0,100.0,NONE" (required - string double distance in meters, or NONE if not available applicable)
//"h_accuracy": "10.0, NONE" (required, string double - actual horizontal accuracy in meters, or NONE if not available)
//"v_accuracy": "10.0, NONE" (required, string double - actual vertical accuracy in meters, or NONE if not available)

// This is tested in a application test, and will show up red in the code coverage tool
- (UALocationEvent*)createLocationEventWithLocation:(CLLocation*)location andProvider:(id<UALocationProviderProtocol>)provider {
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:10];
    [context setValue:[UALocationUtils stringFromDouble:location.coordinate.latitude] forKey:UALocationEventLatitudeKey];
    [context setValue:[UALocationUtils stringFromDouble:location.coordinate.longitude] forKey:UALocationEventLongitudeKey];
    [context setValue:[UALocationUtils stringFromDouble:provider.locationManager.desiredAccuracy] forKey:UALocationEventDesiredAccuracyKey];
    // update_dist
    [context setValue:[UALocationUtils stringFromDouble:provider.locationManager.distanceFilter] forKey:UALocationEventDistanceFilterKey];
    [context setValue:provider.provider forKey:UALocationEventProviderKey];
    [context setValue:[UALocationUtils stringFromDouble:location.horizontalAccuracy] forKey:UALocationEventHorizontalAccuracyKey];
    [context setValue:[UALocationUtils stringFromDouble:location.verticalAccuracy] forKey:UALocationEventVerticalAccuracyKey];
    return [UALocationEvent locationEventWithContext:context];
}

@end

