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
#import "UALocationServicesCommon.h"

/**
 This is the base class for location providers. You should not
 implement this class directly
 */

@interface UABaseLocationProvider : NSObject <CLLocationManagerDelegate, UALocationProviderProtocol> {
    CLLocationManager *locationManager_;
    id <UALocationProviderDelegate> delegate_;
    UALocationProviderStatus serviceStatus_;
    UALocationServiceProviderType *provider_;
}

/** 
 Location manager used for providing location data. Setting this value has
 the side effect of assigning this class as the delegate of the
 new CLLocationManager
 */
@property (nonatomic, retain) CLLocationManager *locationManager;

/// Delegate that receives location updates 
@property (nonatomic, assign) id <UALocationProviderDelegate> delegate;

/** 
 Status of the location service. 
 
 Possible values are
 
 + UALocationProviderUpdating The service is currently updating location
 + UALocationProviderNotUpdating The service is not updating location
 
 */
@property (nonatomic, assign) UALocationProviderStatus serviceStatus;

/// Provider type must be set by subclasses 
@property (nonatomic, copy) UALocationServiceProviderType *provider;

/**
 Sets the purpose on the CLLocationManager locationManger which is displayed to the user
 when the UIAlertView is displayed asking the user for locaiton permission
 @param newPurpose String to be set on the locationManager
 */
- (void)setPurpose:(NSString*)newPurpose;

/**
 Current purpose attached to the CLLocationMananger locationManager
 @return Current purpose on the locationManager
*/
- (NSString*)purpose;

///---------------------------------------------------------------------------------------
/// @name Creating a UABaseLocationProvider
///---------------------------------------------------------------------------------------

- (id)init;
/**
 Initializes the object with a delegate
 @param delegate Delegate object that implements the UALocationProviderDelegate protocol
 */
- (id)initWithDelegate:(id<UALocationProviderDelegate>)delegate;

///---------------------------------------------------------------------------------------
/// @name Location Accuracy
///---------------------------------------------------------------------------------------

/** 
 Calculates location change accuracy
 @param newLocation The updated location from the location service.
 @param oldLocation The location that the new location is compared to. 
 @return YES if the location meets accuracy requirements
 @return NO if the location does not meet accuracy requirements
 */
- (BOOL)locationChangeMeetsAccuracyRequirements:(CLLocation*)newLocation from:(CLLocation*)oldLocation;

///---------------------------------------------------------------------------------------
/// @name Methods to override
///---------------------------------------------------------------------------------------

/**
 Empty method meant to be overridden. 
 @warning Default implementation does nothing
 */
- (void)startProvidingLocation;
/**
 Empty method meant to be overridden. 
 @warning Default implementation does nothing
 */
- (void)stopProvidingLocation;
@end
