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

@implementation UALocationService

#pragma mark -
#pragma mark UALocationService.h
@synthesize minimumTimeBetweenForegroundUpdates = minimumTimeBetweenForegroundUpdates_;
@synthesize lastReportedLocation = lastReportedLocation_;
@synthesize dateOfLastLocation = dateOfLastLocation_;
@synthesize delegate = delegate_;
@synthesize promptUserForLocationServices = promptUserForLocationServices_;
@synthesize automaticLocationOnForegroundEnabled = automaticLocationOnForegroundEnabled_;
@synthesize backgroundLocationServiceEnabled = backroundLocationServiceEnabled_;

#pragma mark -
#pragma mark Object Lifecycle

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // private
    RELEASE_SAFELY(standardLocationProvider_);
    RELEASE_SAFELY(significantChangeProvider_);
    RELEASE_SAFELY(singleLocationProvider_);
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
        // Default CLManagerValues
        // TODO: set these values to something more appropriate
        minimumTimeBetweenForegroundUpdates_ = 120.0;
        [self beginObservingUIApplicationState];
        standardLocationProvider_ = [[UAStandardLocationProvider alloc] initWithDelegate:self];        
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

// TODO: set distanceFilter/desiredAccuracy on location providers as they come back online
- (void)appWillEnterForeground {
    if ([self shouldPerformAutoLocationUpdate]) {
        [self reportCurrentLocation];
    }
    // If the location services were not allowed in the background, and they were tracking when the app entered the background
    // restart them now. 
    if(!backroundLocationServiceEnabled_){
        BOOL startStandard = [UALocationService boolForLocationServiceKey:uaStandardLocationServiceRestartKey];
        BOOL startSignificantChange = [UALocationService boolForLocationServiceKey:uaSignificantChangeServiceRestartKey];
        if (startStandard)[self startReportingLocation]; 
        if (startSignificantChange)[self startReportingSignificantLocationChanges];
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

- (void)appDidEnterBackground {
    if (!backroundLocationServiceEnabled_) {
        if (standardLocationProvider_.serviceStatus == UALocationProviderUpdating) {
            [UALocationService setBool:YES forLocationServiceKey:uaStandardLocationServiceRestartKey];
        }
        else {
            [UALocationService setBool:NO forLocationServiceKey:uaStandardLocationServiceRestartKey];
        }
        if (significantChangeProvider_.serviceStatus == UALocationProviderUpdating){
            [UALocationService setBool:YES forLocationServiceKey:uaSignificantChangeServiceRestartKey];
        }
        else {
            [UALocationService setBool:NO forLocationServiceKey:uaSignificantChangeServiceRestartKey];
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

// These values are stored in NSUserDefaults, necessary for restarting services on foreground
#pragma mark -
#pragma mark UAStandardLocation Location Accuracy and Distance
- (CLLocationDistance)standardLocationDistanceFilter {
    return standardLocationProvider_.distanceFilter;
}

- (void)setStandardLocationDistanceFilter:(CLLocationDistance)distanceFilter {
    [UALocationService setDouble:distanceFilter forLocationServiceKey:uaStandardLocationDistanceFilterKey];
    standardLocationProvider_.distanceFilter = distanceFilter;
}

- (CLLocationAccuracy)standardLocationDesiredAccuracy {
    return standardLocationProvider_.desiredAccuracy;
}

- (void)setStandardLocationDesiredAccuracy:(CLLocationAccuracy)desiredAccuracy{
    [UALocationService setDouble:desiredAccuracy forLocationServiceKey:uaStandardLocationDesiredAccuracyKey];
    standardLocationProvider_.desiredAccuracy = desiredAccuracy;
}



// This is stored in user defaults to assign a purpose to new CLLocationManager objects
// on app foreground
- (NSString*)purpose {
    return [UALocationService objectForLocationServiceKey:uaLocationServicePurposeKey];
}

- (void)setPurpose:(NSString *)purpose {
    NSString* uniquePurpose = [NSString stringWithString:purpose];
    [UALocationService setObject:uniquePurpose forLocationServiceKey:uaLocationServicePurposeKey];
    if (standardLocationProvider_) {
        standardLocationProvider_.purpose = uniquePurpose;
    }
    if (significantChangeProvider_){
        significantChangeProvider_.purpose = uniquePurpose;
    }
}
 
- (CLLocationAccuracy)desiredAccuracyForLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    return (CLLocationAccuracy)[UALocationService doubleForLocationServiceKey:key];
}

- (CLLocationDistance)distanceFilterForLocationSerivceKey:(UALocationServiceNSDefaultsKey*)key {
    return (CLLocationDistance)[UALocationService doubleForLocationServiceKey:key];
}


#pragma mark -
#pragma mark UALocationProviderDelegate Methods

//TODO: Handle traffic from multiple locationProvider callbacks!!
- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider 
       withLocationManager:(CLLocationManager*)locationManager 
didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    // Only use the authorizaiton change callbacks from the standardLocationProvider. 
    // It exists for the life of the UALocaionService callback.
    if(locationProvider != standardLocationProvider_){
        return;
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
        [UALocationService setBool:NO forLocationServiceKey:uaDeprecatedLocationAuthorizationKey];
        [locationProvider stopReportingLocation];
        [self sendErrorToLocationServiceDelegate:error];

    }
    else {
        [self sendErrorToLocationServiceDelegate:error];
    }
}

- (void)UALocationProvider:(id<UALocationProviderProtocol>)locationProvider
       withLocationManager:(CLLocationManager *)locationManager 
         didUpdateLocation:(CLLocation*)newLocation
              fromLocation:(CLLocation*)oldLocation {
    [self sendLocationToAnalytics:newLocation fromProvider:locationProvider];
    self.lastReportedLocation = newLocation; 
    self.dateOfLastLocation = [NSDate date];
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

- (void)sendErrorToLocationServiceDelegate:(NSError *)error {
    if([delegate_ respondsToSelector:@selector(UALocationService:didFailWithError:)]) {
        [delegate_ UALocationService:self didFailWithError:error];
    }
}

#pragma mark UALocationService authorization convenience methods

- (BOOL)isLocationServiceEnabledAndAuthorized {
    BOOL airshipEnabled = [UALocationService airshipLocationServiceEnabled];
    BOOL enabled = [UALocationService locationServicesEnabled];
    BOOL authorized = [UALocationService locationServiceAuthorized];
    return enabled && authorized && airshipEnabled;
}

#pragma mark Standard Location
- (void)startReportingLocation {
    if(!standardLocationProvider_){
        // Factory methods aren't used to avoid setting the delegate twice
        self.standardLocationProvider = [[[UAStandardLocationProvider alloc] init] autorelease];
    }
    [self startReportingLocationWithProvider:standardLocationProvider_];
}

// Keep the standardLocationProvider around for the life of the object to receive didChangeAuthorization 
// callbacks 
- (void)stopReportingLocation {
    [standardLocationProvider_ stopReportingLocation];
}

#pragma mark Significant Change
- (void)startReportingSignificantLocationChanges {
    if(!significantChangeProvider_){
        // Factory methods aren't used to avoid setting the delegate twice
        self.significantChangeProvider = [[[UASignificantChangeProvider alloc] init] autorelease];
    }
    [self startReportingLocationWithProvider:significantChangeProvider_];
}

// Release the significantChangeProvider to prevent double delegate callbacks
// when authorization state changes
- (void)stopReportingSignificantLocationChanges {
    [significantChangeProvider_ stopReportingLocation];
    RELEASE_SAFELY(significantChangeProvider_);
}

#pragma mark -
#pragma mark Single Location Service

// The default values on the core location object are preset to the highest level of accuracy
// TODO: see if we want to leave it this way. 
- (void)reportCurrentLocation {
    if(singleLocationProvider_.serviceStatus == UALocationProviderUpdating) return;    
    if (!singleLocationProvider_) {
        self.singleLocationProvider = [UAStandardLocationProvider  providerWithDelegate:self];
        singleLocationProvider_.purpose = self.purpose;
    }
    [self startReportingLocationWithProvider:singleLocationProvider_];
}

- (void)startReportingLocationWithProvider:(id)locationProvider {
    BOOL authorizedAndEnabled = [self isLocationServiceEnabledAndAuthorized];
    if(promptUserForLocationServices_ || authorizedAndEnabled) {
        [locationProvider startReportingLocation];
    }
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
    [standardLocationProvider_ autorelease];
    standardLocationProvider_ = [standardLocationProvider retain];
    [self setCommonPropertiesOnProvider:standardLocationProvider_];
    standardLocationProvider_.distanceFilter = [self distanceFilterForLocationSerivceKey:uaStandardLocationDistanceFilterKey];
    standardLocationProvider_.desiredAccuracy = [self desiredAccuracyForLocationServiceKey:uaStandardLocationDesiredAccuracyKey];
}

- (UASignificantChangeProvider*)significantChangeProvider {
    return significantChangeProvider_;
}

- (void)setSignificantChangeProvider:(UASignificantChangeProvider *)significantChangeProvider {
    [significantChangeProvider_ autorelease];
    significantChangeProvider_ = [significantChangeProvider retain];
    [self setCommonPropertiesOnProvider:significantChangeProvider_];
}

- (UAStandardLocationProvider*)singleLocationProvider {
    return singleLocationProvider_;
}

- (void)setSingleLocationProvider:(UAStandardLocationProvider *)singleLocationProvider {
    [singleLocationProvider_ autorelease];
    singleLocationProvider_ = [singleLocationProvider retain];
    // distanceFilter and desiredAccuracy are left at default, the most accurate. 
    [self setCommonPropertiesOnProvider:singleLocationProvider_];
}

- (void)setCommonPropertiesOnProvider:(UABaseLocationProvider*)locationProvider {
    locationProvider.delegate = self;
    if(self.purpose) {
        locationProvider.purpose = self.purpose;
    }
}


#pragma mark -
#pragma mark UALocationEvent Analytics

- (void)sendLocationToAnalytics:(CLLocation *)location fromProvider:(id<UALocationProviderProtocol>)provider {
    if (provider == standardLocationProvider_) {
        [self sendLocation:location fromLocationManager:provider.locationManager withUpdateType:uaLocationEventUpdateTypeContinuous];
        
    }
    else if (provider == significantChangeProvider_) {
        [self sendLocation:location fromLocationManager:provider.locationManager withUpdateType:uaLocationEventUpdateTypeChange];
    }
    else if (provider == singleLocationProvider_) {
        [self sendLocation:location fromLocationManager:provider.locationManager withUpdateType:uaLocationEventUpdateTypeSingle];
    }
    else {
        [self sendLocation:location fromLocationManager:provider.locationManager withUpdateType:uaLocationEventUpdateTypeNone];
    }
}

- (void)sendLocation:(CLLocation*)location 
 fromLocationManager:(CLLocationManager*)locationManager 
      withUpdateType:(UALocationEventUpdateType*)updateTypeOrNil {
    UALocationEvent *event = [UALocationEvent locationEventWithLocation:location locationManager:locationManager andUpdateType:updateTypeOrNil];
    [[UAirship shared].analytics addEvent:event];
}

#pragma mark -
#pragma mark Class Methods

+ (void)setObject:(id)object forLocationServiceKey:(UALocationServiceNSDefaultsKey*)key {
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key]; 
}

+(id)objectForLocationServiceKey:(UALocationServiceNSDefaultsKey *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
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
    return [UALocationService boolForLocationServiceKey:uaLocationServiceEnabledKey];
}

// Setting these values will trigger a NSUserDefaults update with a KVO notification
+ (void)setAirshipLocationServiceEnabled:(BOOL)airshipLocationServiceEnabled{
    [UALocationService setBool:airshipLocationServiceEnabled forLocationServiceKey:uaLocationServiceEnabledKey];
}

+ (BOOL) locationServiceAuthorized {
    if ([UALocationService useDeprecatedMethods]){
        NSNumber *deprecatedAuthorization = [UALocationService objectForLocationServiceKey:uaDeprecatedLocationAuthorizationKey];
        // If this is nil, that means an intial value has never been set. Setting the default value of YES allows
        // location services to start on iOS < 4.2 without setting the force prompt flag to YES.
        if (!deprecatedAuthorization) {
            [UALocationService setBool:YES forLocationServiceKey:uaDeprecatedLocationAuthorizationKey];
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
                return YES;
            case kCLAuthorizationStatusAuthorized:
                return YES;
            case kCLAuthorizationStatusDenied:
                return NO;
            case kCLAuthorizationStatusRestricted:
                return NO;
            default:
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
    return ![CLLocationManager respondsToSelector:@selector(locationServicesEnabled)];
}

// This method uses a known depricated method, should be removed in the future. 
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
+ (BOOL)locationServicesEnabled {
    if ([UALocationService useDeprecatedMethods]) {
        // Depricated method call, calling CLLocationManager instance for authorzation
        CLLocationManager *depricatedAuthorization = [[[CLLocationManager alloc] init] autorelease];
        BOOL enabled = [depricatedAuthorization locationServicesEnabled];
        return enabled;
    }
    else {
        return [CLLocationManager locationServicesEnabled];
    }
}
#pragma GCC diagnostic warning "-Wdeprecated-declarations"



@end

