/* Copyright Airship and Contributors */

#import "UAUtils+Internal.h"
#import "UAActionResult.h"
#import "UADispatcher+Internal.h"

// Frameworks
#import <CommonCrypto/CommonDigest.h>

// Airship external libraries
#import "UA_Base64.h"

// UALib
#import "UAUser.h"
#import "UAirship.h"
#import "UARuntimeConfig.h"
#import "UAKeychainUtils+Internal.h"
#import "UARequest+Internal.h"

// C includes
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/xattr.h>
#include <sys/utsname.h>
#include <netinet/in.h>

#if !TARGET_OS_TV   // CoreTelephony not supported in tvOS
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#endif

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

+ (nullable NSString *)nilIfEmpty:(nullable NSString *)str {
    return str.length == 0 ? nil : str;
}

+ (void)getDeviceID:(void (^)(NSString *))completionHandler dispatcher:(nullable UADispatcher *)dispatcher {
    [[UADispatcher backgroundDispatcher] dispatchAsync:^{
        NSString *deviceID = [UAKeychainUtils getDeviceID];
        UADispatcher *completionDispatcher = dispatcher ? : [UADispatcher mainDispatcher];

        [completionDispatcher dispatchAsync:^{
            completionHandler(deviceID);
        }];
    }];
}

+ (NSString *)deviceModelName {
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

+ (NSString *)carrierName {
#if TARGET_OS_TV    // Core Telephony not supported on tvOS
    return nil;
#else
    static CTTelephonyNetworkInfo *netInfo_;
    static dispatch_once_t netInfoDispatchToken_;
    dispatch_once(&netInfoDispatchToken_, ^{
        netInfo_ = [[CTTelephonyNetworkInfo alloc] init];
    });
    return netInfo_.subscriberCellularProvider.carrierName;
#endif
}

+ (NSString *)pluralize:(int)count singularForm:(NSString*)singular
             pluralForm:(NSString*)plural {
    if(count==1)
        return singular;

    return plural;
}

+ (NSString *)getReadableFileSizeFromBytes:(double)bytes {
    if (bytes < 1024)
        return([NSString stringWithFormat:@"%.0f %@",bytes,[self pluralize:bytes singularForm:@"byte" pluralForm:@"bytes"]]);

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

#if !TARGET_OS_TV   // Inbox not supported on tvOS
+ (NSString *)userAuthHeaderString:(UAUserData *)userData {
    return [UAUtils authHeaderStringWithName:userData.username
                                    password:userData.password];
}
#endif

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
    NSArray *formats = @[@"yyyy-MM-dd'T'HH:mm:ss.SSS",
                         @"yyyy-MM-dd'T'HH:mm:ss",
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

+ (nullable UIWindow *)mainWindow:(UIWindowScene *)scene API_AVAILABLE(ios(13.0)){
    // Try to get the primary window of the scene, and fall back on the application's window if necessary.
    return scene.windows.firstObject ?: [self mainWindow];
}

+ (nullable UIWindow *)windowForView:(UIView *)view {
    UIWindow *window;
    while ((view = view.superview)) {
        if ([view isKindOfClass:[UIWindow class]]) {
            window = (UIWindow *)view;
        }
    }
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

    // Iterate through any presented view controllers and find the top-most presentation context
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
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
            mergedResult = UIBackgroundFetchResultFailed;
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

        if ([UAUtils isAlertingPush:notification]) {
            return NO;
        }
    }

    return YES;
}

+ (BOOL)isAlertingPush:(NSDictionary *)notification {
    NSDictionary *apsDict = [notification objectForKey:@"aps"];
    id alert = [apsDict objectForKey:@"alert"];
    if ([alert isKindOfClass:[NSDictionary class]]) {
        if ([alert[@"body"] length]) {
            return YES;
        }
        
        if ([alert[@"loc-key"] length]) {
            return YES;
        }
    } else if ([alert isKindOfClass:[NSString class]] && [alert length]) {
        return YES;
    }
    
    return NO;
}

/**
 * A utility method that takes an APNS-provided device token and returns the decoded Airship device token
 */
+ (NSString *)deviceTokenStringFromDeviceToken:(NSData *)deviceToken {
    NSMutableString *deviceTokenString = [NSMutableString stringWithCapacity:([deviceToken length] * 2)];
    const unsigned char *bytes = (const unsigned char *)[deviceToken bytes];
    
    for (NSUInteger i = 0; i < [deviceToken length]; i++) {
        [deviceTokenString appendFormat:@"%02X", bytes[i]];
    }
    
    return [deviceTokenString lowercaseString];
}

/**
 * A utility method that compares two version strings and determines their order.
 */
+ (NSComparisonResult)compareVersion:(NSString *)version1 toVersion:(NSString *)version2 {
    NSArray *version1Components = [version1 componentsSeparatedByString:@"."];
    NSArray *version2Components = [version2 componentsSeparatedByString:@"."];

    NSInteger index = 0;
    while ([version1Components count] > index || [version2Components count] > index) {
        NSInteger version1Component = [version1Components count] > index ? [[version1Components objectAtIndex:index] integerValue] : 0;
        NSInteger version2Component = [version2Components count] > index ? [[version2Components objectAtIndex:index] integerValue] : 0;
        if (version1Component < version2Component) {
            return NSOrderedAscending;
        } else if (version1Component > version2Component) {
            return NSOrderedDescending;
        }
        index++;
    }

    return NSOrderedSame;
}

/**
 * A utility method that compares two floating points and returns `YES` if the
 * difference between them is less than or equal to the specified accuracy.
 * This allows for minor differences due to errors injected through the
 * transformation of floating point values to and from JSON.
 */
+ (BOOL)float:(CGFloat)float1 isEqualToFloat:(CGFloat)float2 withAccuracy:(CGFloat)accuracy {
    if (float1 == float2) {
        return YES;
    }
    
    CGFloat diff = fabs(float1 - float2);
    if (diff > fabs(accuracy)) {
        return NO;
    }
    
    return YES;
}

+ (NSData*)sha256DigestWithString:(NSString*)input {
    NSData *dataIn = [input dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *dataOut = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(dataIn.bytes, (CC_LONG) dataIn.length, dataOut.mutableBytes);
    return dataOut;
}

+ (NSString *)sha256HashWithString:(NSString*)input {
    NSData *digest = [self sha256DigestWithString:input];

    // convert digest to a byte buffer
    const unsigned char *buffer = (const unsigned char *)[digest bytes];
    if (!buffer) {
        return [NSString string];
    }
    
    NSMutableString *hash = [NSMutableString stringWithCapacity:(CC_SHA256_DIGEST_LENGTH * 2)];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x",buffer[i]];
    }

    return hash;
}

@end
