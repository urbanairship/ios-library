/* Copyright Airship and Contributors */

#if !defined(UA_USE_MODULE_IMPORT)
#define UA_USE_MODULE_IMPORT 1
#endif

#import <Foundation/Foundation.h>

//! Project version number for AirshipCore.
FOUNDATION_EXPORT double AirshipCoreVersionNumber;

//! Project version string for AirshipCore.
FOUNDATION_EXPORT const unsigned char AirshipCoreVersionString[];


#if __has_include("AirshipBasement/AirshipBasement.h")
#import <AirshipBasement/AirshipBasement.h>
#endif
