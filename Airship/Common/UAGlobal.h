/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

typedef enum _UALogLevel {
    UALogLevelUndefined = -1,
    UALogLevelNone = 0,
    UALogLevelError = 1,
    UALogLevelWarn = 2,
    UALogLevelInfo = 3,
    UALogLevelDebug = 4,
    UALogLevelTrace = 5
} UALogLevel;


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

//only log thread if #UA_LOG_THREAD is defined
#ifdef UA_LOG_THREAD
#define UA_LEVEL_LOG UA_LEVEL_LOG_THREAD
#else
#define UA_LEVEL_LOG UA_LEVEL_LOG_NO_THREAD
#endif

extern BOOL uaLoggingEnabled; // Default is true
extern UALogLevel uaLogLevel; // Default is UALogLevelDebug

#define UA_LTRACE(fmt, ...) UA_LEVEL_LOG(UALogLevelTrace, @"T", fmt, ##__VA_ARGS__)
#define UA_LDEBUG(fmt, ...) UA_LEVEL_LOG(UALogLevelDebug, @"D", fmt, ##__VA_ARGS__)
#define UA_LINFO(fmt, ...) UA_LEVEL_LOG(UALogLevelInfo, @"I", fmt, ##__VA_ARGS__)
#define UA_LWARN(fmt, ...) UA_LEVEL_LOG(UALogLevelWarn, @"W", fmt, ##__VA_ARGS__)
#define UA_LERR(fmt, ...) UA_LEVEL_LOG(UALogLevelError, @"E", fmt, ##__VA_ARGS__)

#define UALOG UA_LDEBUG

// constants
#define kAirshipProductionServer @"https://device-api.urbanairship.com"

//legacy paths
#define kUAOldDirectory [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, \
NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString: @"/ua/"]

#define kUAOldDownloadDirectory [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, \
NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingString: @"/"]

// color
#define RGBA(r,g,b,a) [UIColor colorWithRed: r/255.0f green: g/255.0f \
blue: b/255.0f alpha: a]

#define BG_RGBA(r,g,b,a) CGContextSetRGBFillColor(context, r/255.0f, \
g/255.0f, b/255.0f, a)

#define kUpdateFGColor RGBA(255, 131, 48, 1)
#define kUpdateBGColor RGBA(255, 228, 201, 1)

#define kInstalledFGColor RGBA(60, 150, 60, 1)
#define kInstalledBGColor RGBA(185, 220, 185, 1)

#define kDownloadingFGColor RGBA(45, 138, 193, 1)
#define kDownloadingBGColor RGBA(173, 213, 237, 1)

#define kPriceFGColor [UIColor darkTextColor]
#define kPriceBorderColor RGBA(185, 185, 185, 1)
#define kPriceBGColor RGBA(217, 217, 217, 1)

// tag
#define __UA_DEPRECATED __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_NA,__MAC_NA,__IPHONE_3_0,__IPHONE_3_0)

// code block
#define RELEASE_SAFELY(__POINTER) { [__POINTER release]; __POINTER = nil; }

#ifdef _UA_VERSION
#define UA_VERSION @ _UA_VERSION
#else
#define UA_VERSION @ "1.1.2"
#endif

#define UA_VERSION_INTERFACE(CLASSNAME)  \
@interface CLASSNAME : NSObject         \
+ (NSString *)get;                      \
@end


#define UA_VERSION_IMPLEMENTATION(CLASSNAME, VERSION_STR)    \
@implementation CLASSNAME                                   \
+ (NSString *)get {                                         \
return VERSION_STR;                                     \
}                                                           \
@end


#define SINGLETON_INTERFACE(CLASSNAME)  \
+ (CLASSNAME*)shared;\
- (void)forceRelease;


#define SINGLETON_IMPLEMENTATION(CLASSNAME)         \
                                                    \
static CLASSNAME* g_shared##CLASSNAME = nil;        \
\
+ (CLASSNAME*)shared                                \
{                                                   \
if (g_shared##CLASSNAME != nil) {                   \
return g_shared##CLASSNAME;                         \
}                                                   \
\
@synchronized(self) {                               \
if (g_shared##CLASSNAME == nil) {                   \
    g_shared##CLASSNAME = [[self alloc] init];      \
}                                                   \
}                                                   \
\
return g_shared##CLASSNAME;                         \
}                                                   \
\
+ (id)allocWithZone:(NSZone*)zone                   \
{                                                   \
@synchronized(self) {                               \
if (g_shared##CLASSNAME == nil) {                   \
g_shared##CLASSNAME = [super allocWithZone:zone];    \
return g_shared##CLASSNAME;                         \
}                                                   \
}                                                   \
NSAssert(NO, @ "[" #CLASSNAME                       \
" alloc] explicitly called on singleton class.");   \
return nil;                                         \
}                                                   \
\
- (id)copyWithZone:(NSZone*)zone                    \
{                                                   \
return self;                                        \
}                                                   \
\
- (id)retain                                        \
{                                                   \
return self;                                        \
}                                                   \
\
- (oneway void)release                                     \
{                                                   \
}                                                   \
\
- (void)forceRelease {                              \
UALOG(@"Force release "#CLASSNAME"");               \
@synchronized(self) {                               \
if (g_shared##CLASSNAME != nil) {                   \
g_shared##CLASSNAME = nil;                          \
}                                                   \
}                                                   \
[super release];                                    \
}                                                   \
\
- (id)autorelease                                   \
{                                                   \
return self;                                        \
}


#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_4_0
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#define IF_IOS4_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0) \
{ \
__VA_ARGS__ \
}
#else
#define IF_IOS4_OR_GREATER(...)
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_1
#define IF_IOS4_1_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_4_1) \
{ \
__VA_ARGS__ \
}
#else
#define IF_IOS4_1_OR_GREATER(...)
#endif


// Add new __LIB__ macros as necessary
#define __UA_LIB_1_3_0__ "Deprecated in libUAirship-1.3.0"
#define __UA_LIB_1_3_2__ "Deprecated in libUAirship-1.3.2"
#define UA_DEPRECATED(deprecatedMessage) __attribute__((deprecated(deprecatedMessage)))

