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

#import "UAUtils.h"
#import "UAActionResult.h"

// Frameworks
#import <CommonCrypto/CommonDigest.h>

// UA external libraries
#import "UA_Base64.h"

// UALib
#import "UAUser.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAKeychainUtils+Internal.h"
#import "UARequest+Internal.h"

// C includes
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/xattr.h>
#include <netinet/in.h>

@implementation UAUtils

+ (NSString *)connectionType {
    SCNetworkReachabilityFlags flags;
    SCNetworkReachabilityRef reachabilityRef;

    struct sockaddr_in zeroAddress;

    // Put sizeof(zeroAddress) number of 0-bytes at address &zeroAddress
    bzero(&zeroAddress, sizeof(zeroAddress));

    // Set length of sockaddr_in struct
    zeroAddress.sin_len = sizeof(zeroAddress);

    // Set address family to internetwork: UDP, TCP, etc.
    zeroAddress.sin_family = AF_INET;

    reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)&zeroAddress);
    Boolean success = SCNetworkReachabilityGetFlags(reachabilityRef, &flags);
    CFRelease(reachabilityRef);

    // Return early if flags don't return, a connection is required, or the network is unreachable
    if (!success || (flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return kUAConnectionTypeNone;
    }

    NSString *connectionType = kUAConnectionTypeNone;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        connectionType = kUAConnectionTypeWifi;
    }

    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            connectionType = kUAConnectionTypeWifi;
        }
    }

    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        connectionType = kUAConnectionTypeCell;
    }

    return connectionType;
}

+ (NSString *)deviceID {
    return [UAKeychainUtils getDeviceID];
}

+ (NSString *)deviceModelName {
    size_t size;
    
    // Set 'oldp' parameter to NULL to get the size of the data
    // returned so we can allocate appropriate amount of space
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    char *name;
    
    // Allocate the space to store name
    if (!(name = malloc(size))) {
        UA_LERR(@"Out of memory");
        return @"";
    };
    
    // Get the platform name
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    
    // Place name into a string
    NSString *machine = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
    
    // Done with this
    free(name);
    
    return machine;
}

+ (NSString *)pluralize:(int)count singularForm:(NSString*)singular
             pluralForm:(NSString*)plural {
    if(count==1)
        return singular;

    return plural;
}

+ (NSString *)getReadableFileSizeFromBytes:(double)bytes {
    if (bytes < 1024)
        return([NSString stringWithFormat:@"%.0f bytes",bytes]);

    bytes /= 1024.0;
    if (bytes < 1024)
        return([NSString stringWithFormat:@"%1.2f KB",bytes]);

    bytes /= 1024.0;
    if (bytes < 1024)
        return([NSString stringWithFormat:@"%1.2f MB",bytes]);

    bytes /= 1024.0;
    if (bytes < 1024)
        return([NSString stringWithFormat:@"%1.2f GB",bytes]);

    bytes /= 1024.0;
    return([NSString stringWithFormat:@"%1.2f TB",bytes]);
}

+ (void)logFailedRequest:(UARequest *)request
             withMessage:(NSString *)message
               withError:(NSError *)error
            withResponse:(NSHTTPURLResponse *)response {
    UA_LTRACE(@"***** Request ERROR: %@ *****"
              @"\n\tError: %@"
              @"\nRequest:"
              @"\n\tURL: %@"
              @"\n\tHeaders: %@"
              @"\n\tMethod: %@"
              @"\n\tBody: %@"
              @"\nResponse:"
              @"\n\tStatus code: %ld"
              @"\n\tHeaders: %@"
              @"\n\tBody: %@",
              message,
              error,
              [request.URL absoluteString],
              [request.headers description],
              request.method,
              [request.body description],
              (long)[response statusCode],
              [[response allHeaderFields] description],
              [response description]);
}

+ (NSString *)userAuthHeaderString {
    return [UAUtils authHeaderStringWithName:[UAirship inboxUser].username
                                    password:[UAirship inboxUser].password];
}

+ (NSString *)appAuthHeaderString {
    return [UAUtils authHeaderStringWithName:[UAirship shared].config.appKey
                                    password:[UAirship shared].config.appSecret];
}

+ (NSString *)authHeaderStringWithName:(NSString *)username password:(NSString *)password {
    NSString *authString = UA_base64EncodedStringFromData([[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding]);

    //strip carriage return and linefeed characters
    authString = [authString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    authString = [authString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    authString = [NSString stringWithFormat: @"Basic %@", authString];

    return authString;
}

+ (NSDateFormatter *)ISODateFormatterUTC {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];


    return dateFormatter;
}

+ (NSDateFormatter *)ISODateFormatterUTCWithDelimiter {
    NSDateFormatter *dateFormatter = [self ISODateFormatterUTC];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    return dateFormatter;
}

+ (NSDate *)parseISO8601DateFromString:(NSString *)timestamp {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    // All the various formats
    NSArray *formats = @[@"yyyy-MM-dd'T'HH:mm:ss",
                         @"yyyy-MM-dd HH:mm:ss",
                         @"yyyy-MM-dd'T'HH:mm",
                         @"yyyy-MM-dd HH:mm",
                         @"yyyy-MM-dd'T'HH",
                         @"yyyy-MM-dd HH",
                         @"yyyy-MM-dd",
                         @"yyyy-MM",
                         @"yyyy"];

    for (NSString *format in formats) {
        dateFormatter.dateFormat = format;
        NSDate *date = [dateFormatter dateFromString:timestamp];
        if (date) {
            return date;
        }
    }

    return nil;
}

+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)url {
    if (![[NSFileManager defaultManager] fileExistsAtPath: [url path]]) {
        return NO;
    }
    NSError *error = nil;
    BOOL success = [url setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if (!success) {
        UA_LERR(@"Error excluding %@ from backup %@", [url lastPathComponent], error);
    }

    return success;
}

+ (UIWindow *)mainWindow {
    UIWindow *window;

    id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
    // Prefer the window property on the app delegate, if accessible
    if ([appDelegate respondsToSelector:@selector(window)]){
        window = appDelegate.window;
    }

    // Otherwise fall back on the first window of the app's collection, if present.
    window = window ?: [[UIApplication sharedApplication].windows firstObject];

    return window;
}

/**
 * A utility method that grabs the top-most view controller for the main application window.
 * May return nil if a suitable view controller cannot be found.
 */
+ (UIViewController *)topController {

    UIWindow *window = [self mainWindow];

    UIViewController *topController = window.rootViewController;

    if (!topController) {
        UA_LDEBUG(@"unable to find top controller");
        return nil;
    }

    BOOL presented = NO;
    UIModalPresentationStyle presentationStyle = topController.modalPresentationStyle;

    // Iterate through any presented view controllers and find the top-most presentation context
    while (topController.presentedViewController) {
        presented = YES;
        // UIModalPresentationCurrentContext allows a view controller to use the presentation style of its modal parent.
        if (topController.presentedViewController.modalPresentationStyle != UIModalPresentationCurrentContext) {
            presentationStyle = topController.presentedViewController.modalPresentationStyle;
        }
        topController = topController.presentedViewController;
    }

    // Custom modal presentation could leave us in an unpredictable display state
    if (presented && presentationStyle == UIModalPresentationCustom) {
        UA_LDEBUG(@"top view controller is using a custom presentation style, returning nil");
        return nil;
    }
    
    return topController;
}

/**
 * A utility method that takes an array of fetch results and returns the merged result
 */
+ (UIBackgroundFetchResult)mergeFetchResults:(NSArray<NSNumber *> *)fetchResults {
    UIBackgroundFetchResult mergedResult = UIBackgroundFetchResultNoData;

    for (NSNumber *fetchResult in fetchResults) {
        if (fetchResult.intValue == UIBackgroundFetchResultNewData) {
            return UIBackgroundFetchResultNewData;
        } else if (fetchResult.intValue == UIBackgroundFetchResultFailed) {
            mergedResult = fetchResult.intValue;
        }
    }

    return mergedResult;
}

+ (BOOL)isSilentPush:(NSDictionary *)notification {
    NSDictionary *apsDict = [notification objectForKey:@"aps"];
    if (apsDict) {
        id badgeNumber = [apsDict objectForKey:@"badge"];
        NSString *soundName = [apsDict objectForKey:@"sound"];

        if (badgeNumber || soundName.length) {
            return NO;
        }

        id alert = [apsDict objectForKey:@"alert"];
        if ([alert isKindOfClass:[NSDictionary class]]) {
            if ([alert[@"body"] length]) {
                return NO;
            }

            if ([alert[@"loc-key"] length]) {
                return NO;
            }
        } else if ([alert isKindOfClass:[NSString class]] && [alert length]) {
            return NO;
        }
    }

    return YES;
}

@end
