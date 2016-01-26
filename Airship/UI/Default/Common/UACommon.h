/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#if __has_include("AirshipKit/AirshipKit.h")
#import <AirshipKit/AirshipKit.h>
#else
#import "AirshipLib.h" 
#endif

#define UA_SAMPLE_UI_MIN_SUPPORTED_SDK 60000

// Suppress all warnings unless the user's base sdk is newer than the airship's base sdk
#if (IPHONE_OS_VERSION_MIN_REQUIRED <= UA_SAMPLE_UI_MIN_SUPPORTED_SDK)
#define UA_SUPPRESS_UI_DEPRECATION_WARNINGS _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
#else
#define UA_SUPPRESS_UI_DEPRECATION_WARNINGS
#endif

@interface UACommon : NSObject
@end
