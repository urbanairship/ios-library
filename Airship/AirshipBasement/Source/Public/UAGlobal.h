/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import "UALegacyLoggingBridge.h"

#define UA_LEVEL_LOG(level, fmt, ...) \
do { \
   [UALegacyLoggingBridge logWithLevel:level function:@(__PRETTY_FUNCTION__) line:__LINE__ message:^NSString * { return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; }]; \
} while(0)


#define UA_LTRACE(fmt, ...) UA_LEVEL_LOG(5, fmt, ##__VA_ARGS__)
#define UA_LDEBUG(fmt, ...) UA_LEVEL_LOG(4, fmt, ##__VA_ARGS__)
#define UA_LINFO(fmt, ...) UA_LEVEL_LOG(3, fmt, ##__VA_ARGS__)
#define UA_LWARN(fmt, ...) UA_LEVEL_LOG(2, fmt, ##__VA_ARGS__)
#define UA_LERR(fmt, ...) UA_LEVEL_LOG(1, fmt, ##__VA_ARGS__)
#define UALOG UA_LDEBUG
