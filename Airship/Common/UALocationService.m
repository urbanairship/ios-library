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

#import "UALocationService.h"
#import "UALocationService+Internal.h"
#import "UABaseLocationProvider.h"
#import "UAGlobal.h"
#import "UAStandardLocationProvider.h"
#import "UASignificantChangeProvider.h"
#import "UAirship.h"
#import "UALocationEvent.h"
#import "UAAnalytics.h"

NSString *const UALocationServiceBestAvailableSingleLocationKey = @"UABestAvailableLocation";

@implementation UALocationService

#pragma mark -
#pragma mark UALocationService.h
@synthesize minimumTimeBetweenForegroundUpdates = minimumTimeBetweenForegroundUpdates_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize dateOfLastLocation = dateOfLastLocation_;
@synthesize shouldStartReportingStandardLocation = shouldStartReportingStandardLocation_;
@synthesize shouldStartReportingSignificantChange = shouldStartReportingSignificantChange_;
@synthesize bestAvailableSingleLocation = bestAvailableSingleLocation_;
@synthesize singleLocationBackgroundIdentifier = singleLocationBackgroundIdentifier_;
@synthesize delegate = delegate_;
@synthesize promptUserForLocationServices = promptUserForLocationServices_;
@synthesize automaticLocationOnForegroundEnabled = automaticLocationOnForegroundEnabled_;
@synthesize backgroundLocationServiceEnabled = backroundLocationServiceEnabled_;


#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    self.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    standardLocationProvider_.delegate = nil;
    significantChangeProvider_.delegate = nil;
    // private
    RELEASE_SAFELY(standardLocationProvider_);
    RELEASE_SAFELY(significantChangeProvider_);
    RELEASE_SAFELY(bestAvailableSingleLocation_);
    // Single location deleagate is set to nil in stop method
    [self stopSingleLocation];
    //
    // public
    RELEASE_SAFELY(lastReportedLocation_);
    RELEASE_SAFELY(dateOfLastLocation_);
    //
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        minimumTimeBetweenForegroundUpdates_ = 120.0;
        [self beginObservingUIApplicationState];
        // The standard location setter method pulls the distanceFilter and desiredAccuracy from
        // NSUserDefaults. 
        [self setStandardLocationProvider:[[[UAStandardLocationProvider alloc] init] autorelease]]; 
        self.singleLocationBackgroundIdentifier = UIBackgroundTaskInvalid;
    }
    return self;
}

- (id)initWithPurpose:(NSString*)purpose {
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
    if(!backroundLocationServiceEnabled_){
        UALOG(@"Restarting location providers that were previously running");
        if (shouldStartReportingStandardLocation_)[self startReportingStandardLocation]; 
        if (shouldStartReportingSignificantChange_)[self startReportingSignificantLocationChanges];
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
    if (!backroundLocationServiceEnabled_) {
        // Single Location service does not get stopped here, there is a background task that will stop automatically
        // when a location is reported, or the service times out (default timeout 30 seconds 16APR12)
        if (standardLocationProvider_.serviceStatus == UALocationProviderUpdating){
            [self stopReportingStandardLocation];
            // Setup the service to restart since it was running, and background services are not enabled
            // and shutting down the service sets shouldStartReportingStandardLocation to NO;
            self.shouldStartReportingStandardLocation = YES;
        }
        if (significantChangeProvider_.serviceStatus == UALocationProviderUpdating){
            [self stopReportingSignificantLocationChanges];
            // See the comment above, service needs to be setup to restart
            self.shouldStartReportingSignificantChange = YES;
        }
    }
}

- (BOOL)shouldPerformAutoLocationUpdate {
    // if not enabled, bail
    if (!automaticLocationOnForegroundEnabled_) return NO; 
    // If the date is nil, then a report is needed
    if (!dateOfLastLocation_) return YES;
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:dateOfLastLocation_];
    if(elapsedTime < minimumTimeBetweenForegroundUpdates_) {
        return NO;
    }
    return YES;
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

// These values are stored in NSUserDefaults, necessary for restarting services on foreground
#pragma mark -
#pragma mark UAStandardLocation Location Accuracy and Distance
- (CLLocationDistance)standardLocationDistanceFilter {
    return standardLocationProvider_.distanceFilter;
}

- (void)setStandardLocationDistanceFilter:(CLLocationDistance)distanceFilter {
    [UALocationService setDouble:distanceFilter forLocationServiceKey:UAStandardLocationDistanceFilterKey];
    standardLocationProvider_.distanceFilter = distanceFilter;
}

- (CLLocationAccuracy)standardLocationDesiredAccuracy {
    return standardLocationProvider_.desiredAccuracy;
}

- (void)setStandardLocationDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy{
    [UALocationService setDouble:desiredAccuracy forLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
    standardLocationProvider_.desiredAccuracy = desiredAccuracy;
}

// This is stored in user defaults to assign a purpose to new CLLocationManager objects
// on app foreground
- (NSString*)purpose {
    return [UALocationService objectForLocationServiceKey:UALocationServicePurposeKey];
}

- (void)setPurpose:(NSString *)purpose {
    NSString* uniquePurpose = [NSString stringWithString:purpose];
    [UALocationService setObject:uniquePurpose forLocationServiceKey:UALocationServicePurposeKey];
    if (standardLocationProvider_) {
        standardLocationProvider_.purpose = uniquePurpose;
    }
    if (significantChangeProvider_){
        significantChangeProvider_.purpose = uniquePurpose;
    }
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
    if(locationProvider != standardLocationProvider_){
        return;
    }
    if ([delegate_ respondsToSelector:@selector(locationService:didChangeAuthorizationStatus:)]) {
        [delegate_ locationService:self didChangeAuthorizationStatus:status];
    }
}


- (void)locationProvider:(id<UALocationProviderProtocol>)locationProvider 
     withLocationManager:(CLLocationManager*)locationManager 
        didFailWithError:(NSError*)error {
    UALOG(@"Location service did fail with error %@", error.description);
    // Catch kCLErrorDenied for iOS < 4.2
    switch (error.code) {
        case kCLErrorDenied:
            [UALocationService setBool:NO forLocationServiceKey:UADeprecatedLocationAuthorizationKey];
            [locationProvider stopReportingLocation];
            break;
        case kCLErrorNetwork:
            [locationProvider stopReportingLocation];
            break;
        default:
            break;
    }
    [self sendErrorToLocationServiceDelegate:error];
}

- (void)sendErrorToLocationServiceDelegate:(NSError *)error {
    if([delegate_ respondsToSelector:@selector(locationService:didFailWithError:)]) {
        [delegate_ locationService:self didFailWithError:error];
    }
}

// This method just directs traffic
- (void)locationProvider:(id<UALocationProviderProtocol>)locationProvider
     withLocationManager:(CLLocationManager *)locationManager 
       didUpdateLocation:(CLLocation*)newLocation
            fromLocation:(CLLocation*)oldLocation {
    UALOG(@"Location service did update to location %@ from location %@", newLocation, oldLocation);
    if (locationProvider == singleLocationProvider_) {
        [self singleLocationDidUpdateToLocation:newLocation fromLocation:oldLocation];
        return;
    }
    if (locationProvider == standardLocationProvider_) {
        [self standardLocationDidUpdateToLocation:newLocation fromLocation:oldLocation];
        return;
    }
    if (locationProvider == significantChangeProvider_){
        [self significantChangeDidUpdateToLocation:newLocation fromLocation:oldLocation];
    }
}



#pragma mark -
#pragma mark Standard Location Methods
- (void)startReportingStandardLocation {
    UALOG(@"Attempt to start standard location service");
    if(!standardLocationProvider_){
        // Factory methods aren't used to avoid setting the delegate twice
        self.standardLocationProvider = [[[UAStandardLocationProvider alloc] init] autorelease];
    }
    [self startReportingLocationWithProvider:standardLocationProvider_];
}

// Keep the standardLocationProvider around for the life of the object to receive didChangeAuthorization 
// callbacks 
- (void)stopReportingStandardLocation {
    UALOG(@"Location service stop reporting standard location");
    [standardLocationProvider_ stopReportingLocation];
    self.shouldStartReportingStandardLocation = NO;
}

// Eventually add the auto shutdown to this method as well if locations aren't 
// improving
- (void)standardLocationDidUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation *)oldLocation {
    if(newLocation.horizontalAccuracy < standardLocationProvider_.desiredAccuracy || standardLocationProvider_.desiredAccuracy <= kCLLocationAccuracyBest) {
        [self reportLocationToAnalytics:newLocation fromProvider:standardLocationProvider_];
        if ([delegate_ respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)]) {
            [delegate_ locationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
        }
    }
}

- (CLLocation*)location {
    return standardLocationProvider_.location;
}

#pragma mark Significant Change
- (void)startReportingSignificantLocationChanges {
    UALOG(@"Attempt to start significant change service");
    if(!significantChangeProvider_){
        // Factory methods aren't used to avoid setting the delegate twice
        self.significantChangeProvider = [[[UASignificantChangeProvider alloc] init] autorelease];
    }
    [self startReportingLocationWithProvider:significantChangeProvider_];
}

// Release the significantChangeProvider to prevent double delegate callbacks
// when authorization state changes
- (void)stopReportingSignificantLocationChanges {
    UALOG(@"Stop reporting significant change");
    [significantChangeProvider_ stopReportingLocation];
    self.shouldStartReportingSignificantChange = NO;
    // Nil out the delegate to prevent extraneous delegate callbacks
    significantChangeProvider_.delegate = nil;
}

// Report any valid location from Sig change, validity is checked by the providers themselves
// Valid values have horizontalAccuracy > 0 and timestamps that are no older than the 
// maximum, which is set on the provider as well
- (void)significantChangeDidUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    [self reportLocationToAnalytics:newLocation fromProvider:significantChangeProvider_];
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
    if(self.singleLocationServiceStatus == UALocationProviderUpdating){
        return;
    }
    if(![self isLocationServiceEnabledAndAuthorized]) {
        return;
    }
    if (!singleLocationProvider_) {
        self.singleLocationProvider = [UAStandardLocationProvider  providerWithDelegate:self];
    }
    // Setup the background task
    // This exits the same way as the performSelector:withObject:afterDelay method
    self.singleLocationBackgroundIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // This eventually calls stopSingleLocation, which shuts down the background task
        // Same task as performSelector:withObject:afterDelay, so if that works, this works
        [self shutdownSingleLocationWithTimeoutError];
    }];
    // Setup error timeout
    [self performSelector:@selector(shutdownSingleLocationWithTimeoutError) 
               withObject:nil
               afterDelay:self.timeoutForSingleLocationService];
    [singleLocationProvider_ startReportingLocation];
}

// Shuts down the single location service with a location timeout error
// Covered in Application tests
- (void)shutdownSingleLocationWithTimeoutError {
    NSError* locationError = [self locationTimeoutError];
    [self stopSingleLocationWithError:locationError];
}

- (void)singleLocationDidUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    // If desiredAccuracy is set at or better than kCLAccuracyBest, send back everything
    if (newLocation.horizontalAccuracy < singleLocationProvider_.desiredAccuracy || singleLocationProvider_.desiredAccuracy <= kCLLocationAccuracyBest){
        if ([delegate_ respondsToSelector:@selector(locationService:didUpdateToLocation:fromLocation:)]) {
            [delegate_ locationService:self didUpdateToLocation:newLocation fromLocation:oldLocation];
        }
        [self stopSingleLocationWithLocation:newLocation];
    }
    else {
        if (bestAvailableSingleLocation_.horizontalAccuracy < newLocation.horizontalAccuracy) {
            UALOG(@"Updated location %@\nreplaced current best location %@", self.bestAvailableSingleLocation, newLocation);
            self.bestAvailableSingleLocation = newLocation;
        }
    }
    UALOG(@"Location %@ did not meet accuracy requirement", newLocation);
}

//Make sure stopSingleLocation is called to shutdown background task
- (void)stopSingleLocationWithLocation:(CLLocation*)location {
    // If there are ever more performRequests, use the other cancel method call
    // (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    UALOG(@"Single location acquired location %@", location);
    [self reportLocationToAnalytics:location fromProvider:singleLocationProvider_];
    [self stopSingleLocation];
}

//Make sure stopSingleLocation is called to shutdown background task
- (void)stopSingleLocationWithError:(NSError*)locationError {
    // If there are ever more performRequests, use the other cancel method call
    // (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    UALOG(@"Single location failed with error %@", locationError);
    if ([delegate_ respondsToSelector:@selector(locationService:didFailWithError:)]) {
        [delegate_ locationService:self didFailWithError:locationError];
    }
    if (bestAvailableSingleLocation_) {
        [self reportLocationToAnalytics:bestAvailableSingleLocation_ fromProvider:singleLocationProvider_];
    }
    [self stopSingleLocation];  
}

// Every stopLocation method turtles down here
// this cancels the background task
- (void)stopSingleLocation {
    // If there are ever more performRequests, use the other cancel method call
    // (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (singleLocationProvider_.serviceStatus == UALocationProviderUpdating) {
        [singleLocationProvider_ stopReportingLocation];
    }
    singleLocationProvider_.delegate = nil;
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
    if(promptUserForLocationServices_ || authorizedAndEnabled) {
        UALOG(@"Starting location service");
        if(locationProvider.delegate == nil){
            locationProvider.delegate = self;
        }
        if (locationProvider == standardLocationProvider_) {
            self.shouldStartReportingStandardLocation = YES;
        }
        if (locationProvider == significantChangeProvider_) {
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

- (UAStandardLocationProvider*)standardLocationProvider {
    return standardLocationProvider_;
}

- (void)setStandardLocationProvider:(UAStandardLocationProvider *)standardLocationProvider {
    [standardLocationProvider_ stopReportingLocation];
    standardLocationProvider_.delegate = nil;
    [standardLocationProvider_ release];
    standardLocationProvider_ = [standardLocationProvider retain];
    [self setCommonPropertiesOnProvider:standardLocationProvider_];
    standardLocationProvider_.distanceFilter = [self distanceFilterForLocationServiceKey:UAStandardLocationDistanceFilterKey];
    standardLocationProvider_.desiredAccuracy = [self desiredAccuracyForLocationServiceKey:UAStandardLocationDesiredAccuracyKey];
}

- (UASignificantChangeProvider*)significantChangeProvider {
    return significantChangeProvider_;
}

- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider {
    [significantChangeProvider_ release];
    significantChangeProvider_ = [significantChangeProvider retain];
    [self setCommonPropertiesOnProvider:significantChangeProvider_];
}

- (UAStandardLocationProvider*)singleLocationProvider {
    return singleLocationProvider_;
}

// The distanceFilter is not set as a side effect with this setter.
- (void)setSingleLocationProvider:(UAStandardLocationProvider *)singleLocationProvider {
    [singleLocationProvider_ release];
    singleLocationProvider_ = [singleLocationProvider retain];
    singleLocationProvider_.distanceFilter = kCLDistanceFilterNone;
    singleLocationProvider_.desiredAccuracy = [self desiredAccuracyForLocationServiceKey:UASingleLocationDesiredAccuracyKey];
    [self setCommonPropertiesOnProvider:singleLocationProvider_];
}

- (void)setCommonPropertiesOnProvider:(id <UALocationProviderProtocol>)locationProvider{
    locationProvider.delegate = self;
    if(self.purpose) {
        locationProvider.purpose = self.purpose;
    }
}

- (void)setAutomaticLocationOnForegroundEnabled:(BOOL)automaticLocationOnForegroundEnabled {
    if (automaticLocationOnForegroundEnabled_ == automaticLocationOnForegroundEnabled) {
        return;
    }
    else {
        automaticLocationOnForegroundEnabled_ = automaticLocationOnForegroundEnabled;
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
    if (provider == standardLocationProvider_) {
        [self reportLocation:location fromLocationManager:provider.locationManager withUpdateType:UALocationEventUpdateTypeContinuous];
    }
    else if (provider == significantChangeProvider_) {
        [self reportLocation:location fromLocationManager:provider.locationManager withUpdateType:UALocationEventUpdateTypeChange];
    }
    else if (provider == singleLocationProvider_) {
        [self reportLocation:location fromLocationManager:provider.locationManager withUpdateType:UALocationEventUpdateTypeSingle];
    }
    else {
        [self reportLocation:location fromLocationManager:provider.locationManager withUpdateType:UALocationEventUpdateTypeNone];
    }
}


- (void)reportLocation:(CLLocation*)location 
   fromLocationManager:(CLLocationManager*)locationManager 
        withUpdateType:(UALocationEventUpdateType*)updateTypeOrNil {
    UALOG(@"Sending location to analytics -> %@ update type %@", location, updateTypeOrNil);
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:location locationManager:locationManager andUpdateType:updateTypeOrNil];
    [[UAirship shared].analytics addEvent:event];
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

+ (void)setObject:(id)object forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    UALOG(@"Writing object %@ to user defaults for key %@", object, key);
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key]; 
}

+(id)objectForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    id object = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    UALOG(@"Returning object %@ from user defaults for key %@", object, key);
    return object;
}

+ (void)setBool:(BOOL)boolValue forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    [UALocationService setObject:[NSNumber numberWithBool:boolValue] forLocationServiceKey:key];
}

+ (BOOL)boolForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

+ (void)setDouble:(double)doubleValue forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    [UALocationService setObject:[NSNumber numberWithDouble:doubleValue] forLocationServiceKey:key];
}

+ (double)doubleForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:key];
}

+ (BOOL)airshipLocationServiceEnabled {
    return [UALocationService boolForLocationServiceKey:UALocationServiceEnabledKey]; 
}

// Setting these values will trigger a NSUserDefaults update with a KVO notification
+ (void)setAirshipLocationServiceEnabled:(BOOL)airshipLocationServiceEnabled{
    [UALocationService setBool:airshipLocationServiceEnabled forLocationServiceKey:UALocationServiceEnabledKey];
}

+ (BOOL) locationServiceAuthorized {
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
                UALOG(@"Location authorization kCLAuthorizationStatusNotDetermined");
                return YES;
            case kCLAuthorizationStatusAuthorized:
                UALOG(@"Location authorization kCLAuthorizationStatusAuthorized");
                return YES;
            case kCLAuthorizationStatusDenied:
                UALOG(@"Location authorization kCLAuthorizationStatusDenied");
                return NO;
            case kCLAuthorizationStatusRestricted:
                UALOG(@"Location authorization kCLAuthorizationStatusRestricted");
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

+ (BOOL)useDeprecatedMethods { ;
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

- (NSError*)locationTimeoutError {
    // TODO: This needs to be setup in the localization bundle
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:@"The location service timed out before receiving a location that meets accuracy requirements" forKey:NSLocalizedDescriptionKey];
    if (bestAvailableSingleLocation_) {
        [userInfo setObject:bestAvailableSingleLocation_ forKey:UALocationServiceBestAvailableSingleLocationKey];
    }
    NSError *error = [NSError errorWithDomain:UALocationServiceTimeoutError code:UALocationServiceTimedOut userInfo:userInfo];
    return error;
}



@end

