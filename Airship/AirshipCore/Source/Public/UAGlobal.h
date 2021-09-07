/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>


#define UA_LEVEL_LOG_THREAD(level, levelString, fmt, ...) \
    do { \
        if (uaLogLevel >= level) { \
            NSString *thread = ([[NSThread currentThread] isMainThread]) ? @"M" : @"B"; \
            NSLog((@"[%@] [%@] => %s [Line %d] " fmt), levelString, thread, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
        } \
    } while(0)

#define UA_LEVEL_LOG_NO_THREAD(level, levelString, fmt, ...) \
    do { \
        if (uaLogLevel >= level) { \
            NSLog((@"[%@] %s [Line %d] " fmt), levelString, __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__); \
        } \
    } while(0)

#define UA_LEVEL_LOG_IMPLEMENTATION(fmt, ...) \
    do { \
        if (uaLogLevel >= 1) { \
            NSLog((@"🚨Airship Implementation Error🚨 - " fmt), ##__VA_ARGS__); \
        } \
    } while(0)

//only log thread if #UA_LOG_THREAD is defined
#ifdef UA_LOG_THREAD
#define UA_LEVEL_LOG UA_LEVEL_LOG_THREAD
#else
#define UA_LEVEL_LOG UA_LEVEL_LOG_NO_THREAD
#endif

extern NSInteger uaLogLevel; // Default is UALogLevelError

#define UA_LTRACE(fmt, ...) UA_LEVEL_LOG(5, @"T", fmt, ##__VA_ARGS__)
#define UA_LDEBUG(fmt, ...) UA_LEVEL_LOG(4, @"D", fmt, ##__VA_ARGS__)
#define UA_LINFO(fmt, ...) UA_LEVEL_LOG(3, @"I", fmt, ##__VA_ARGS__)
#define UA_LWARN(fmt, ...) UA_LEVEL_LOG(2, @"W", fmt, ##__VA_ARGS__)
#define UA_LERR(fmt, ...) UA_LEVEL_LOG(1, @"E", fmt, ##__VA_ARGS__)
#define UA_LIMPERR(fmt, ...) UA_LEVEL_LOG_IMPLEMENTATION(fmt, ##__VA_ARGS__)
#define UALOG UA_LDEBUG

#define UA_WEAKIFY(var) __weak __typeof(var) UAWeak_##var = var;
#define UA_STRONGIFY(var) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
__strong __typeof(var) var = UAWeak_##var; \
_Pragma("clang diagnostic pop")
