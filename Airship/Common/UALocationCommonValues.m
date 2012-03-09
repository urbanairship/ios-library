//
//  UALocationCommonValues.m
//  AirshipLib
//
//  Created by Matt Hooge on 3/8/12.
//  Copyright (c) 2012 Urban Airship. All rights reserved.
//

#import "UALocationCommonValues.h"

UALocationServiceProviderType *const uaLocationServiceProviderGps = @"GPS";
UALocationServiceProviderType *const uaLocationServiceProviderNetwork = @"NETWORK";
UALocationServiceProviderType *const uaLocationServiceProviderUnknown = @"UNKNOWN";

#pragma mark -
#pragma mark NSUserPreferences keys for location service persistence
UALocationServiceNSDefaultsKey *const uaLocationServiceAllowedKey = @"UALocationServiceAllowed";
UALocationServiceNSDefaultsKey *const uaLocationServiceEnabledKey = @"UALocationServiceEnabled";
UALocationServiceNSDefaultsKey *const uaLocationServicePurposeKey = @"UALocationServicePurpose";
UALocationServiceNSDefaultsKey *const uaStandardLocationServiceRestartKey = @"standardLocationServiceStatusRestart";
UALocationServiceNSDefaultsKey *const uaSignificantChangeServiceRestartKey = @"significantChangeServiceStatusRestart";
UALocationServiceNSDefaultsKey *const uaStandardLocationDistanceFilterKey = @"standardLocationDistanceFilter";
UALocationServiceNSDefaultsKey *const uaStandardLocationDesiredAccuracyKey = @"standardLocationDesiredAccuracy";

@implementation UALocationCommonValues

@end


