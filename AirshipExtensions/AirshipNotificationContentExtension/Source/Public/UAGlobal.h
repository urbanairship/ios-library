/* Copyright Airship and Contributors */

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
     *
     * Used for critical errors, parse exceptions and other situations that cannot be gracefully handled.
     */
    UALogLevelError = 1,

    /**
     * Log warning messages.
     *
     * Used for API deprecations, invalid setup and other potentially problematic situations.
     */
    UALogLevelWarn = 2,

    /**
     * Log informative messages.
     *
     * Used for reporting general SDK status.
     */
    UALogLevelInfo = 3,

    /**
     * Log debugging messages.
     *
     * Used for reporting general SDK status with more detailed information.
     */
    UALogLevelDebug = 4,

    /**
     * Log detailed tracing messages.
     *
     * Used for reporting highly detailed SDK status that can be useful when debugging and troubleshooting.
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
                NSLog((@"🚨Airship Implementation Error🚨 - " fmt), ##__VA_ARGS__); \
            } else { \
                NSLog((@"Airship Implementation Error - " fmt), ##__VA_ARGS__); \
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

#define UA_PREVIEW_WARNING \
NSLog(@"\n\n" \
      "\t                       AIRSHIP PREVIEW RELEASE                       \n"\
      "\t                                                                     \n"\
      "\t  THIS AIRSHIP SDK IS RELEASED AS A DEVELOPER PREVIEW VERSION AND    \n"\
      "\t  MAY CONTAIN BUGS, ERRORS, DEFECTS, HARMFUL COMPONENTS AND MAY NOT  \n"\
      "\t  BE COMPATIBLE WITH THE FINAL VERSION OF THE APPLICABLE THIRD PARTY \n"\
      "\t  OPERATING SYSTEM. ACCORDINGLY, AIRSHIP IS PROVIDING THE LICENSE ON \n"\
      "\t  AN “AS IS” BASIS AND NOT FOR USE IN PRODUCTION.                    \n"\
      "\t                            _..--=--..._                             \n"\
      "\t                         .-'            '-.  .-.                     \n"\
      "\t                        /.'              '.\\/  /                    \n"\
      "\t                       |=-                -=| (                      \n"\
      "\t                        \\'.              .'/\\  \\                   \n"\
      "\t                         '-.,_____ _____.-'  '-'                     \n"\
      "\t                              [_____]=8                              \n\n\n");

#ifdef UA_PREVIEW
#define UA_BUILD_WARNINGS UA_PREVIEW_WARNING
#else
#define UA_BUILD_WARNINGS
#endif

#define UA_WEAKIFY(var) __weak __typeof(var) UAWeak_##var = var;

#define UA_STRONGIFY(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong __typeof(var) var = UAWeak_##var; \
_Pragma("clang diagnostic pop")
