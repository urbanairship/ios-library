/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
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

#import "UALocationService+Internal.h"
#import "UABaseLocationProvider.h"
#import "UAGlobal.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UAirship.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"

#define kUALocationServiceDefaultPurpose @"Push to Location"
#define kUALocationServiceSingleLocationDefaultTimeout 30.0

NSString * const UALocationServiceBestAvailableSingleLocationKey = @"UABestAvailableLocation";

@implementation UALocationService

#pragma mark -
#pragma mark Object Lifecycle

+ (void)initialize {
    [self registerNSUserDefaults];
}

- (void)dealloc {
    self.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.standardLocationProvider.delegate = nil;
    self.significantChangeProvider.delegate = nil;

    // private
    self.standardLocationProvider = nil;
    self.significantChangeProvider = nil;
    self.bestAvailableSingleLocation = nil;

    // Single location deleagate is set to nil in stop method
    [self stopSingleLocation];

    // public
    self.lastReportedLocation = nil;
    self.dateOfLastLocation = nil;

    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        self.minimumTimeBetweenForegroundUpdates = 120.0;
        [self beginObservingUIApplicationState];
        // The standard location setter method pulls the distanceFilter and desiredAccuracy from
        // NSUserDefaults. 
        [self setStandardLocationProvider:[[[UAStandardLocationProvider alloc] init] autorelease]]; 
        self.singleLocationBackgroundIdentifier = UIBackgroundTaskInvalid;
    }
    return self;
}

- (id)initWithPurpose:(NSString *)purpose {
    self = [self init];
    if(self){
        if (purpose){
            [self setPurpose:purpose];
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

- (void)restartPreviousLocationServices {
    if (!self.backgroundLocationServiceEnabled) {
        UALOG(@"Restarting location providers that were previously running");
        if (self.shouldStartReportingStandardLocation) {
            [self startReportingStandardLocation];
        }
        
        if (self.shouldStartReportingSignificantChange) {
            [self startReportingSignificantLocationChanges];
        }
    }
}

- (void)appWillEnterForeground {
    UALOG(@"Location service did receive appWillEnterForeground");
    if ([self shouldPerformAutoLocationUpdate]) {
        [self reportCurrentLocation];
    }
    // If the location services were not allowed in the background, and they were tracking when the app entered the background
    // restart them now. 
    [self restartPreviousLocationServices];
}

- (void)appDidEnterBackground {
    UALOG(@"Location service did enter background");
    if (!self.backgroundLocationServiceEnabled) {
        // Single Location service does not get stopped here, there is a background task that will stop automatically
        // when a location is reported, or the service times out (default timeout 30 seconds 16APR12)
        if (self.standardLocationProvider.serviceStatus == UALocationProviderUpdating){
            [self stopReportingStandardLocation];
            // Setup the service to restart since it was running, and background services are not enabled
            // and shutting down the service sets shouldStartReportingStandardLocation to NO;
            self.shouldStartReportingStandardLocation = YES;
        }
        if (self.significantChangeProvider.serviceStatus == UALocationProviderUpdating){
            [self stopReportingSignificantLocationChanges];
            // See the comment above, service needs to be setup to restart
            self.shouldStartReportingSignificantChange = YES;
        }
    }
}

- (BOOL)shouldPerformAutoLocationUpdate {
    // if not enabled, bail
    if (!self.automaticLocationOnForegroundEnabled) return NO;
    // If the date is nil, then a report is needed
    if (!self.dateOfLastLocation) return YES;
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:self.dateOfLastLocation];
    if(elapsedTime < self.minimumTimeBetweenForegroundUpdates) {
        return NO;
    }
    return YES;
}

#pragma mark -
#pragma mark UALocationProviderStatus

- (UALocationProviderStatus) standardLocationServiceStatus {
    return self.standardLocationProvider.serviceStatus;
}

- (UALocationProviderStatus) significantChangeServiceStatus {
    return self.significantChangeProvider.serviceStatus;
}

- (UALocationProviderStatus) singleLocationServiceStatus {
    return self.singleLocationProvider.serviceStatus;
}

// These values are stored in NSUserDefaults, necessary for restarting services on foreground
#pragma mark -
#pragma mark UAStandardLocation Location Accuracy and Distance
- (CLLocationDistance)standardLocationDistanceFilter {
    return self.standardLocationProvider.distanceFilter;
}

- (void)setStandardLocationDistanceFilter:(CLLocationDistance)distanceFilter {
    [UALocationService setDouble:distanceFilter forLocationServiceKey:UAStandardLocationDistanceFilterKey];
    self.standardLocationProvider.distanceFilter = distanceFilter;
}

- (CLLocationAccuracy)standardLocationDesiredAccuracy {
    return self.standardLocationProvider.desiredAccuracy;
}

- (void)setStandardLocationDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy{
    [UALocationService setDouble:desiredAccuracy forLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
    self.standardLocationProvider.desiredAccuracy = desiredAccuracy;
}

// This is stored in user defaults to assign a purpose to new CLLocationManager objects
// on app foreground
- (NSString*)purpose {
    return [UALocationService objectForLocationServiceKey:UALocationServicePurposeKey];
}

- (void)setPurpose:(NSString *)purpose {
    [UALocationService setObject:purpose forLocationServiceKey:UALocationServicePurposeKey];

    self.standardLocationProvider.purpose = purpose;
    self.significantChangeProvider.purpose = purpose;
}

#pragma mark -
#pragma mark Desired Accuracy and Distance Filter setters
- (CLLocationAccuracy)desiredAccuracyForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    return (CLLocationAccuracy)[UALocationService doubleForLocationServiceKey:key];
}

- (CLLocationDistance)distanceFilterForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    return (CLLocationDistance)[UALocationService doubleForLocationServiceKey:key];
}


#pragma mark -
#pragma mark UALocationProviderDelegate Methods

// Providers shut themselves down when authorization is denied. 
- (void)locationProvider:(id<UALocationProviderProtocol>)locationProvider 
     withLocationManager:(CLLocationManager*)locationManager 
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UALOG(@"Location service did change authorization status %d", status);
    // Only use the authorization change callbacks from the standardLocationProvider. 
    // It exists for the life of the UALocationService callback.
    if(locationProvider != self.standardLocationProvider){
        return;
    }
    if ([self.delegate respondsToSelector:@selector(locationService:didChangeAuthorizationStatus:)]) {
        [self.delegate locationService:self didChangeAuthorizationStatus:status];
    }
}


- (void)locationProvider:(id<UALocationProviderProtocol>)locationProvider 
     withLocationManager:(CLLocationManager*)locationManager 
        didFailWithError:(NSError*)error {
    UALOG(@"Location service did fail with error %@", error.description);
    // There is different logic for the single location service, since it could be a background
    // task
    if (error.code == kCLErrorDenied) {
        [UALocationService setBool:NO forLocationServiceKey:UADeprecatedLocationAuthorizationKey];
    }
    if (locationProvider == self.singleLocationProvider) {
        [self stopSingleLocationWithError:error];
        return;
    }
    if([self.delegate respondsToSelector:@selector(locationService:didFailWithError:)]) {
        [self.delegate locationService:self didFailWithError:error];
    }
}

// This method just directs traffic
- (void)locationProvider:(id<UALocationProviderProtocol>)locationProvider
     withLocationManager:(CLLocationManager *)locationManager 
       didUpdateLocation:(CLLocation *)newLocation
            fromLocation:(CLLocation *)oldLocation {
    UALOG(@"Location service did update to location %@ from location %@", newLocation, oldLocation);
    if (locationProvider == self.singleLocationProvider) {
        [self singleLocationDidUpdateToLocation:newLocation fromLocation:oldLocation];
        return;
    }
    if (locationProvider == self.standardLocationProvider) {
        [self standardLocationDidUpdateToLocation:newLocation fromLocation:oldLocation];
        return;
    }
    if (locationProvider == self.significantChangeProvider){
        [self significantChangeDidUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}



#pragma mark -
#pragma mark Standard Location Methods
- (void)startReportingStandardLocation {
    UALOG(@"Attempt to start standard location service");
    if (!self.standardLocationProvider) {
        // Factory methods aren't used to avoid setting the delegate twice
        self.standardLocationProvider = [[[UAStandardLocationProvider alloc] init] autorelease];
    }

    [self startReportingLocationWithProvider:self.standardLocationProvider];
}

// Keep the standardLocationProvider around for the life of the object to receive didChangeAuthorization 
// callbacks 
- (void)stopReportingStandardLocation {
    UALOG(@"Location service stop reporting standard location");
    [self.standardLocationProvider stopReportingLocation];
    self.shouldStartReportingStandardLocation = NO;
}

// Eventually add the auto shutdown to this method as well if locations aren't 
// improving
- (void)standardLocationDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation *)oldLocation {
    if (newLocation.horizontalAccuracy < self.standardLocationProvider.desiredAccuracy || self.standardLocationProvider.desiredAccuracy <= kCLLocationAccuracyBest) {
        [self reportLocationToAnalytics:newLocation fromProvider:self.standardLocationProvider];
        if ([self.delegate respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)]) {
            [self.delegate locationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
        }
    }
}

- (CLLocation *)location {
    return self.standardLocationProvider.location;
}

#pragma mark Significant Change
- (void)startReportingSignificantLocationChanges {
    UALOG(@"Attempt to start significant change service");
    if (!self.significantChangeProvider) {
        // Factory methods aren't used to avoid setting the delegate twice
        self.significantChangeProvider = [[[UASignificantChangeProvider alloc] init] autorelease];
    }

    [self startReportingLocationWithProvider:self.significantChangeProvider];
}

// Release the significantChangeProvider to prevent double delegate callbacks
// when authorization state changes
- (void)stopReportingSignificantLocationChanges {
    UALOG(@"Stop reporting significant change");
    [self.significantChangeProvider stopReportingLocation];
    self.shouldStartReportingSignificantChange = NO;
    
    // Remove delegate to prevent extraneous delegate callbacks
    self.significantChangeProvider.delegate = nil;
}

// Report any valid location from Sig change, validity is checked by the providers themselves
// Valid values have horizontalAccuracy > 0 and timestamps that are no older than the 
// maximum, which is set on the provider as well
- (void)significantChangeDidUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    [self reportLocationToAnalytics:newLocation fromProvider:self.significantChangeProvider];
    if ([self.delegate respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)]) {
        [self.delegate locationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}

#pragma mark -
#pragma mark Single Location Service

- (NSTimeInterval)timeoutForSingleLocationService {
    return (NSTimeInterval)[UALocationService doubleForLocationServiceKey:UASingleLocationTimeoutKey];
}

- (void)setTimeoutForSingleLocationService:(NSTimeInterval)timeoutForSingleLocationService {
    [UALocationService setDouble:timeoutForSingleLocationService forLocationServiceKey:UASingleLocationTimeoutKey];
}

- (CLLocationAccuracy)singleLocationDesiredAccuracy {
    return [self desiredAccuracyForLocationServiceKey:UASingleLocationDesiredAccuracyKey];
}

- (void)setSingleLocationDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy {
    [UALocationService setDouble:desiredAccuracy forLocationServiceKey:UASingleLocationDesiredAccuracyKey];
}

- (void)reportCurrentLocation {
    // If the single location provider is nil, this will evaluate to false, and a 
    // new location provider will be instantiated. 
    if (self.singleLocationServiceStatus == UALocationProviderUpdating) {
        return;
    }
    
    if (![self isLocationServiceEnabledAndAuthorized]) {
        return;
    }
    
    if (!self.singleLocationProvider) {
        self.singleLocationProvider = [UAStandardLocationProvider providerWithDelegate:self];
    }
    
    // Setup the background task
    // This exits the same way as the performSelector:withObject:afterDelay method
    self.singleLocationBackgroundIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // This eventually calls stopSingleLocation, which shuts down the background task
        // Same task as performSelector:withObject:afterDelay, so if that works, this works
        [self shutdownSingleLocationWithTimeoutError];
    }];
    self.singleLocationProvider.delegate = self;
    [self.singleLocationProvider startReportingLocation];
}

// Shuts down the single location service with a location timeout error
// Covered in Application tests
- (void)shutdownSingleLocationWithTimeoutError {
    NSError *locationError = [self locationTimeoutError];
    [self stopSingleLocationWithError:locationError];
}

- (void)singleLocationDidUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    // Setup error timeout
    if (!self.singleLocationShutdownScheduled) {
        [self performSelector:@selector(shutdownSingleLocationWithTimeoutError)
                   withObject:nil
                   afterDelay:self.timeoutForSingleLocationService];
        self.singleLocationShutdownScheduled = YES;
    }

    // If desiredAccuracy is set at or better than kCLAccuracyBest, send back everything
    if (newLocation.horizontalAccuracy < self.singleLocationProvider.desiredAccuracy) {
        if ([self.delegate respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)]) {
            [self.delegate locationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
        }
        [self stopSingleLocationWithLocation:newLocation];
    }
    else {
        UALOG(@"Location %@ did not meet accuracy requirement", newLocation);
        if (self.bestAvailableSingleLocation.horizontalAccuracy < newLocation.horizontalAccuracy) {
            UALOG(@"Updated location %@\nreplaced current best location %@", self.bestAvailableSingleLocation, newLocation);
            self.bestAvailableSingleLocation = newLocation;
        }
    }
}

//Make sure stopSingleLocation is called to shutdown background task
- (void)stopSingleLocationWithLocation:(CLLocation *)location {
    UALOG(@"Single location acquired location %@", location);
    [self reportLocationToAnalytics:location fromProvider:self.singleLocationProvider];
    [self stopSingleLocation];
}

//Make sure stopSingleLocation is called to shutdown background task
- (void)stopSingleLocationWithError:(NSError *)locationError {
    UALOG(@"Single location failed with error %@", locationError);
    if ([self.delegate respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)] && self.bestAvailableSingleLocation) {
        [self.delegate locationService:self didUpdateToLocation:self.bestAvailableSingleLocation fromLocation:nil];
    }

    if (self.bestAvailableSingleLocation) {
        [self reportLocationToAnalytics:self.bestAvailableSingleLocation fromProvider:self.singleLocationProvider];
    }
    
    BOOL notifyDelegate = [self.delegate respondsToSelector:@selector(locationService:didFailWithError:)];
    // Don't notify in case of a background error, there is most likely no way to recover
    if (self.singleLocationBackgroundIdentifier == UIBackgroundTaskInvalid && notifyDelegate) {
        [self.delegate locationService:self didFailWithError:locationError];
    }
    [self stopSingleLocation];  
}

// Every stopLocation method turtles down here
// this cancels the background task
- (void)stopSingleLocation {
    if (self.singleLocationShutdownScheduled) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(shutdownSingleLocationWithTimeoutError) object:nil];
        self.singleLocationShutdownScheduled = NO;
    }
    [self.singleLocationProvider stopReportingLocation];
    self.singleLocationProvider.delegate = nil;
    UALOG(@"Shutdown single location background task");
    // Order is import if this task is refactored, as execution terminates very quickly with
    // endBackgroundTask. The background task will be invalidated. 
    [[UIApplication sharedApplication] endBackgroundTask:self.singleLocationBackgroundIdentifier];
    self.singleLocationBackgroundIdentifier = UIBackgroundTaskInvalid;
}

#pragma mark -
#pragma mark Common Methods for Providers

- (void)startReportingLocationWithProvider:(id<UALocationProviderProtocol>)locationProvider {
    BOOL authorizedAndEnabled = [self isLocationServiceEnabledAndAuthorized];
    if (self.promptUserForLocationServices || authorizedAndEnabled) {
        UALOG(@"Starting location service");
        // Delegates are set to nil when the service is shut down
        if(locationProvider.delegate == nil){
            locationProvider.delegate = self;
        }
        if (locationProvider == self.standardLocationProvider) {
            self.shouldStartReportingStandardLocation = YES;
        }
        if (locationProvider == self.significantChangeProvider) {
            self.shouldStartReportingSignificantChange = YES;
        }
        [locationProvider startReportingLocation];
        return;
    }
    UALOG(@"Location service not authorized or not enabled");
}

#pragma mark -
#pragma mark UALocationProviders Get/Set Methods
//
// releases the previous LocationProvider and retains the new one
// sets the delegate of the provider to self
//

- (UAStandardLocationProvider *)standardLocationProvider {
    return _standardLocationProvider;
}

- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider {
    [_standardLocationProvider stopReportingLocation];
    _standardLocationProvider.delegate = nil;
    [_standardLocationProvider autorelease];
    
    _standardLocationProvider = [standardLocationProvider retain];
    [self setCommonPropertiesOnProvider:_standardLocationProvider];
    _standardLocationProvider.distanceFilter = [self distanceFilterForLocationServiceKey:UAStandardLocationDistanceFilterKey];
    _standardLocationProvider.desiredAccuracy = [self desiredAccuracyForLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
}

- (UASignificantChangeProvider *)significantChangeProvider {
    return _significantChangeProvider;
}

- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider {
    [_significantChangeProvider autorelease];
    _significantChangeProvider = [significantChangeProvider retain];
    [self setCommonPropertiesOnProvider:_significantChangeProvider];
}

- (UAStandardLocationProvider *)singleLocationProvider {
    return _singleLocationProvider;
}

// The distanceFilter is not set as a side effect with this setter.
- (void)setSingleLocationProvider:(UAStandardLocationProvider *)singleLocationProvider {
    [_singleLocationProvider autorelease];
    _singleLocationProvider = [singleLocationProvider retain];
    _singleLocationProvider.distanceFilter = kCLDistanceFilterNone;
    _singleLocationProvider.desiredAccuracy = [self desiredAccuracyForLocationServiceKey:UASingleLocationDesiredAccuracyKey];
    [self setCommonPropertiesOnProvider:_singleLocationProvider];
}

- (void)setCommonPropertiesOnProvider:(id <UALocationProviderProtocol>)locationProvider{
    locationProvider.delegate = self;
    if (self.purpose) {
        locationProvider.purpose = self.purpose;
    }
}

- (void)setAutomaticLocationOnForegroundEnabled:(BOOL)automaticLocationOnForegroundEnabled {
    if (_automaticLocationOnForegroundEnabled == automaticLocationOnForegroundEnabled) {
        return;
    }
    else {
        _automaticLocationOnForegroundEnabled = automaticLocationOnForegroundEnabled;
        if (automaticLocationOnForegroundEnabled) {
            [self reportCurrentLocation];
        }//if(automatic
    }//else
}


#pragma mark -
#pragma mark UALocationEvent Analytics
// All analytics events are covered in application testing because of the dependency on 
// UAirship

- (void)reportLocationToAnalytics:(CLLocation *)location fromProvider:(id<UALocationProviderProtocol>)provider {
    UALOG(@"Reporting location %@ to analytics from provider %@", location, provider);
    self.lastReportedLocation = location;
    self.dateOfLastLocation = location.timestamp;
    UALocationEvent *event = nil;
    if (provider == self.standardLocationProvider) {
        event = [UALocationEvent locationEventWithLocation:location provider:provider andUpdateType:UALocationEventUpdateTypeContinuous];
    }
    else if (provider == self.significantChangeProvider) {
        event = [UALocationEvent locationEventWithLocation:location provider:provider andUpdateType:UALocationEventUpdateTypeChange];
    }
    else if (provider == self.singleLocationProvider) {
        event = [UALocationEvent locationEventWithLocation:location provider:provider andUpdateType:UALocationEventUpdateTypeSingle];
    }
    else {
        event = [UALocationEvent locationEventWithLocation:location provider:provider andUpdateType:UALocationEventUpdateTypeNone];
    }
    [self sendEventToAnalytics:event];
}


- (void)reportLocation:(CLLocation *)location
   fromLocationManager:(CLLocationManager *)locationManager
        withUpdateType:(UALocationEventUpdateType *)updateTypeOrNil {
    UALOG(@"Sending location to analytics -> %@ update type %@", location, updateTypeOrNil);
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:location locationManager:locationManager andUpdateType:updateTypeOrNil];
    [self sendEventToAnalytics:event];
}

- (void)sendEventToAnalytics:(UALocationEvent *)locationEvent {
    UAAnalytics *analytics = [[UAirship shared] analytics];
    [analytics addEvent:locationEvent];
}

#pragma mark -
#pragma mark Authorization convenience 

- (BOOL)isLocationServiceEnabledAndAuthorized {
    BOOL airshipEnabled = [UALocationService airshipLocationServiceEnabled];
    BOOL enabled = [UALocationService locationServicesEnabled];
    BOOL authorized = [UALocationService locationServiceAuthorized];
    return enabled && authorized && airshipEnabled;
}

#pragma mark -
#pragma mark Class Methods

+ (void)setObject:(id)object forLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key]; 
}

+ (id)objectForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (void)setBool:(BOOL)boolValue forLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    [UALocationService setObject:[NSNumber numberWithBool:boolValue] forLocationServiceKey:key];
}

+ (BOOL)boolForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

+ (void)setDouble:(double)doubleValue forLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    [UALocationService setObject:[NSNumber numberWithDouble:doubleValue] forLocationServiceKey:key];
}

+ (double)doubleForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}

+ (BOOL)airshipLocationServiceEnabled {
    return [UALocationService boolForLocationServiceKey:UALocationServiceEnabledKey]; 
}

// Setting these values will trigger a NSUserDefaults update with a KVO notification
+ (void)setAirshipLocationServiceEnabled:(BOOL)airshipLocationServiceEnabled{
    [UALocationService setBool:airshipLocationServiceEnabled forLocationServiceKey:UALocationServiceEnabledKey];
}

+ (BOOL)locationServiceAuthorized {
    if ([UALocationService useDeprecatedMethods]){
        UALOG(@"Using deprecated authorization methods");
        NSNumber *deprecatedAuthorization = [UALocationService objectForLocationServiceKey:UADeprecatedLocationAuthorizationKey];
        // If this is nil, that means an intial value has never been set. Setting the default value of YES allows
        // location services to start on iOS < 4.2 without setting the force prompt flag to YES.
        if (!deprecatedAuthorization) {
            [UALocationService setBool:YES forLocationServiceKey:UADeprecatedLocationAuthorizationKey];
            return YES;
        }
        else {
            return [deprecatedAuthorization boolValue];
        }
    }
    else {
        CLAuthorizationStatus authorization = [CLLocationManager authorizationStatus];
        switch (authorization) {
            case kCLAuthorizationStatusNotDetermined:
            case kCLAuthorizationStatusAuthorized:
                return YES;
            case kCLAuthorizationStatusDenied:
            case kCLAuthorizationStatusRestricted:
                return NO;
            default:
                UALOG(@"Unexpected value for authorization");
                return NO;
        }
    }
}

// convenience method for devs
+ (BOOL)coreLocationWillPromptUserForPermissionToRun {
    BOOL enabled = [UALocationService locationServicesEnabled];
    BOOL authorized = [UALocationService locationServiceAuthorized];
    return !(enabled && authorized);
}

+ (BOOL)useDeprecatedMethods {
    return ![CLLocationManager respondsToSelector:@selector(authorizationStatus)];
}

// This method uses a known deprecated method, should be removed in the future. 
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
+ (BOOL)locationServicesEnabled {
    if ([UALocationService useDeprecatedMethods]) {
        // deprecated method call, calling CLLocationManager instance for authorization
        CLLocationManager *deprecatedAuthorization = [[[CLLocationManager alloc] init] autorelease];
        BOOL enabled = [deprecatedAuthorization locationServicesEnabled];
        return enabled;
    }
    else {
        return [CLLocationManager locationServicesEnabled];
    }
}
#pragma GCC diagnostic warning "-Wdeprecated-declarations"

- (NSError *)locationTimeoutError {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:@"The location service timed out before receiving a location that meets accuracy requirements" forKey:NSLocalizedDescriptionKey];
    if (self.bestAvailableSingleLocation) {
        [userInfo setObject:self.bestAvailableSingleLocation forKey:UALocationServiceBestAvailableSingleLocationKey];
    }
    NSError *error = [NSError errorWithDomain:UALocationServiceTimeoutError code:UALocationServiceTimedOut userInfo:userInfo];
    return error;
}

// Register the NSUserDefaults for the UALocationService
+ (void)registerNSUserDefaults {
    NSMutableDictionary *defaultPreferences = [NSMutableDictionary dictionaryWithCapacity:3];
    // UALocationService default values
    [defaultPreferences setValue:[NSNumber numberWithBool:NO] forKey:UALocationServiceEnabledKey];
    [defaultPreferences setValue:kUALocationServiceDefaultPurpose forKey:UALocationServicePurposeKey];
    //kCLLocationAccuracyThreeKilometers works, since it is also a double, this may change in future
    [defaultPreferences setValue:[NSNumber numberWithDouble:kCLLocationAccuracyThreeKilometers]
                          forKey:UAStandardLocationDistanceFilterKey];
    [defaultPreferences setValue:[NSNumber numberWithDouble:kCLLocationAccuracyThreeKilometers]
                          forKey:UAStandardLocationDesiredAccuracyKey];
    [defaultPreferences setValue:[NSNumber numberWithDouble:kCLLocationAccuracyHundredMeters]
                          forKey:UASingleLocationDesiredAccuracyKey];
    [defaultPreferences setValue:[NSNumber numberWithDouble:kUALocationServiceSingleLocationDefaultTimeout]
                          forKey:UASingleLocationTimeoutKey];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
}



@end

