/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

#import "UAUtils.h"

// Frameworks
#import <CommonCrypto/CommonDigest.h>

// UA external libraries
#import "UA_SBJSON.h"
#import "UA_Base64.h"
#import "UAHTTPConnection.h"

// UALib
#import "UAUser.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAKeychainUtils.h"

// C includes
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation UAUtils


+ (NSString *)md5:(NSString *)sourceString  {
    const char *cStr = [sourceString UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (unsigned int)strlen(cStr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

+ (NSString *)deviceID {
    return [UAKeychainUtils getDeviceID];
}

+ (NSString *) UUID {
    //create a new UUID
  CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
  //get the string representation of the UUID
    NSString *uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
  
    return [uuidString autorelease];
}

+ (NSString *)deviceModelName {
    size_t size;
    
    // Set 'oldp' parameter to NULL to get the size of the data
    // returned so we can allocate appropriate amount of space
    sysctlbyname("hw.machine", NULL, &size, NULL, 0); 
    
    // Allocate the space to store name
    char *name = malloc(size);
    
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

+ (NSString*)urlEncodedStringWithString:(NSString *)string encoding:(NSStringEncoding)encoding
{
    /*
     * Taken from http://madebymany.com/blog/url-encoding-an-nsstring-on-ios
     */

    CFStringRef result = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)string, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[] ", CFStringConvertNSStringEncodingToEncoding(encoding));
    
    /* autoreleased string */
    NSString* value = [NSString stringWithString:(NSString*)result];
    CFRelease(result);
    
    return value;
}

+ (UAHTTPRequest *)UAHTTPUserRequestWithURL:(NSURL *)url method:(NSString *)method {
    if (![UAirship shared].ready) {
        return nil;
    }
    
    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:url];
    request.HTTPMethod = method;
    
    request.username = [UAUser defaultUser].username;
    request.password = [UAUser defaultUser].password;
    
    
    return request;
}

+ (UAHTTPRequest *)UAHTTPRequestWithURL:(NSURL *)url method:(NSString *)method {
    if (![UAirship shared].ready) {
        return nil;
    }
    
    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:url];
    request.HTTPMethod = method;
    
    request.username = [UAirship shared].config.appKey;
    request.password = [UAirship shared].config.appSecret;
    
    return request;
    
}

+ (void)logFailedRequest:(UAHTTPRequest *)request withMessage:(NSString *)message {
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
          @"\n\tBody: %@"
          @"\nUsing U/P: [ %@ / %@ ]",
          message,
          request.error,
          request.url,
          [request.headers description],
          request.HTTPMethod,
          [request.body description],
          (long)[request.response statusCode],
          [[request.response allHeaderFields] description],
          [request.responseData description],
          request.username,
          request.password);
}

+ (NSString *)userAuthHeaderString {
    NSString *username = [UAUser defaultUser].username;
    NSString *password = [UAUser defaultUser].password;
    NSString *authString = UA_base64EncodedStringFromData([[NSString stringWithFormat:@"%@:%@", username, password] dataUsingEncoding:NSUTF8StringEncoding]);
    
    //strip carriage return and linefeed characters
    authString = [authString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    authString = [authString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    authString = [NSString stringWithFormat: @"Basic %@", authString];
    
    return authString;
}

+ (NSDateFormatter *)ISODateFormatterUTC {
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setTimeStyle:NSDateFormatterFullStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    return dateFormatter;
}

@end
