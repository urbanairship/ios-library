/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <UIKit/UIKit.h>

/**
 * Represents the possible log levels.
 */
typedef NS_ENUM(NSInteger, UALogLevel) {
    /**
     * Undefined log level.
     */
    UALogLevelUndefined = -1,

    /**
     * No log messages.
     */
    UALogLevelNone = 0,

    /**
     * Log error messages.
     */
    UALogLevelError = 1,

    /**
     * Log warning messages.
     */
    UALogLevelWarn = 2,

    /**
     * Log informative messages.
     */
    UALogLevelInfo = 3,

    /**
     * Log debugging messages.
     */
    UALogLevelDebug = 4,

    /**
     * Log detailed tracing messages.
     */
    UALogLevelTrace = 5
};


#define UA_LEVEL_LOG_THREAD(level, levelString, fmt, ...) \
    do { \
        if (uaLoggingEnabled && uaLogLevel >= level) { \
            NSString *thread = ([[NSThread currentThread] isMainThread]) ? @"M" : @"B"; \
            NSLog((@"[%@] [%@] => %s [Line %d] " fmt), levelString, thread, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
        } \
    } while(0)

#define UA_LEVEL_LOG_NO_THREAD(level, levelString, fmt, ...) \
    do { \
        if (uaLoggingEnabled && uaLogLevel >= level) { \
            NSLog((@"[%@] %s [Line %d] " fmt), levelString, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
        } \
    } while(0)

#define UA_LEVEL_LOG_IMPLEMENTATION(fmt, ...) \
    do { \
        if (uaLoggingEnabled && uaLogLevel >= UALogLevelError) { \
            if (uaLoudImpErrorLoggingEnabled) { \
                NSLog((@"🚨Urban Airship Implementation Error🚨 - " fmt), ##__VA_ARGS__); \
            } else { \
                NSLog((@"Urban Airship Implementation Error - " fmt), ##__VA_ARGS__); \
            } \
        } \
    } while(0)

//only log thread if #UA_LOG_THREAD is defined
#ifdef UA_LOG_THREAD
#define UA_LEVEL_LOG UA_LEVEL_LOG_THREAD
#else
#define UA_LEVEL_LOG UA_LEVEL_LOG_NO_THREAD
#endif

extern BOOL uaLoggingEnabled; // Default is YES
extern UALogLevel uaLogLevel; // Default is UALogLevelError
extern BOOL uaLoudImpErrorLoggingEnabled; // Default is YES

#define UA_LTRACE(fmt, ...) UA_LEVEL_LOG(UALogLevelTrace, @"T", fmt, ##__VA_ARGS__)
#define UA_LDEBUG(fmt, ...) UA_LEVEL_LOG(UALogLevelDebug, @"D", fmt, ##__VA_ARGS__)
#define UA_LINFO(fmt, ...) UA_LEVEL_LOG(UALogLevelInfo, @"I", fmt, ##__VA_ARGS__)
#define UA_LWARN(fmt, ...) UA_LEVEL_LOG(UALogLevelWarn, @"W", fmt, ##__VA_ARGS__)
#define UA_LERR(fmt, ...) UA_LEVEL_LOG(UALogLevelError, @"E", fmt, ##__VA_ARGS__)
#define UA_LIMPERR(fmt, ...) UA_LEVEL_LOG_IMPLEMENTATION(fmt, ##__VA_ARGS__)

#define UALOG UA_LDEBUG

// constants
#define kUAAirshipProductionServer @"https://device-api.urbanairship.com"
#define kUAAnalyticsProductionServer @"https://combine.urbanairship.com"
#define kUAProductionLandingPageContentURL @"https://dl.urbanairship.com/aaa"


#define UA_SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(THE_CODE) \
do { \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
THE_CODE; \
_Pragma("clang diagnostic pop") \
} while (0)

#define UA_PREVIEW_WARNING \
NSLog(@"\n\n" \
      "\t                    URBAN AIRSHIP PREVIEW RELEASE                    \n"\
      "\t                                                                     \n"\
      "\t  THIS URBAN AIRSHIP SDK IS RELEASED AS A DEVELOPER PREVIEW VERSION  \n"\
      "\t  AND MAY CONTAIN BUGS, ERRORS, DEFECTS, HARMFUL COMPONENTS AND MAY  \n"\
      "\t  NOT BE COMPATIBLE WITH THE FINAL VERSION OF THE APPLICABLE THIRD   \n"\
      "\t  PARTY OPERATING SYSTEM. ACCORDINGLY, URBAN AIRSHIP IS PROVIDING    \n"\
      "\t  THE LICENSE ON AN “AS IS” BASIS  AND NOT FOR USE IN PRODUCTION.    \n"\
      "\t                            _..--=--..._                             \n"\
      "\t                         .-'            '-.  .-.                     \n"\
      "\t                        /.'              '.\\/  /                    \n"\
      "\t                       |=-                -=| (                      \n"\
      "\t                        \'.              .'/\\  \\                   \n"\
      "\t                         '-.,_____ _____.-'  '-'                     \n"\
      "\t                              [_____]=8                              \n\n\n");

#ifdef UA_PREVIEW
#define UA_BUILD_WARNINGS UA_PREVIEW_WARNING
#else
#define UA_BUILD_WARNINGS
#endif
