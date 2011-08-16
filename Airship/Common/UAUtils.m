/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
#import "UA_ASIHTTPRequest.h"

// UALib
#import "UAUser.h"
#import "UAirship.h"

// C includes
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation UAUtils

+ (NSString *)udidHash {
    NSString* udid = [[UIDevice currentDevice] uniqueIdentifier];
    const char *cStr = [udid UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result);
    return [NSString stringWithFormat:
                            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                            result[0], result[1], result[2], result[3],
                            result[4], result[5], result[6], result[7],
                            result[8], result[9], result[10], result[11],
                            result[12], result[13], result[14], result[15]
                            ];

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

#pragma mark -
#pragma mark ASIHTTPRequest helper methods

+ (UA_ASIHTTPRequest *)requestWithURL:(NSURL *)url method:(NSString *)method
                             delegate:(id)delegate finish:(SEL)selector {
    
    return [self requestWithURL:url method:method delegate:delegate
                         finish:selector fail:@selector(requestWentWrong:)];
}

+ (UA_ASIHTTPRequest *)requestWithURL:(NSURL *)url method:(NSString *)method
                             delegate:(id)delegate finish:(SEL)finishSelector fail:(SEL)failSelector {
    
    if (![UAirship shared].ready) {
        return nil;
    }
    
    UA_ASIHTTPRequest *request = [UA_ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:method];
    request.username = [UAirship shared].appId;
    request.password = [UAirship shared].appSecret;
    request.delegate = delegate;
    request.timeOutSeconds = 60;
    [request setDidFinishSelector:finishSelector];
    [request setDidFailSelector:failSelector];
    
    return request;
}

+ (UA_ASIHTTPRequest *)userRequestWithURL:(NSURL *)url method:(NSString *)method
                                 delegate:(id)delegate finish:(SEL)selector {
    return [self userRequestWithURL:url method:method delegate:delegate
                             finish:selector fail:@selector(requestWentWrong:)];
}

+ (UA_ASIHTTPRequest *)userRequestWithURL:(NSURL *)url method:(NSString *)method
                                 delegate:(id)delegate finish:(SEL)finishSelector fail:(SEL)failSelector {
    
    if (![UAirship shared].ready) {
        return nil;
    }
    
    UA_ASIHTTPRequest *request = [UA_ASIHTTPRequest requestWithURL:url];
    [request setRequestMethod:method];
    request.username = [UAUser defaultUser].username;
    request.password = [UAUser defaultUser].password;
    request.delegate = delegate;
    request.timeOutSeconds = 60;
    [request setDidFinishSelector:finishSelector];
    [request setDidFailSelector:failSelector];
    
    return request;
}

+ (id)responseFromRequest:(UA_ASIHTTPRequest *)request {
    return [UAUtils parseJSON:request.responseString];
}

+ (id)parseJSON:(NSString *)responseString {
    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    id result = [parser objectWithString:responseString];
    [parser release];
    return result;
}

+ (void)requestWentWrong:(UA_ASIHTTPRequest*)request {
    [self requestWentWrong:request keyword:nil];
}

+ (void)requestWentWrong:(UA_ASIHTTPRequest*)request keyword:(NSString *)keyword{
    UALOG(@"\n***** Request ERROR %@*****"
          @"\n\tError: %@"
          @"\nRequest:"
          @"\n\tURL: %@"
          @"\n\tHeaders: %@"
          @"\n\tMethod: %@"
          @"\n\tBody: %@"
          @"\nResponse:"
          @"\n\tStatus code: %d"
          @"\n\tHeaders: %@"
          @"\n\tBody: %@"
          @"\nUsing U/P: [ %@ / %@ ]",
          keyword ? [NSString stringWithFormat:@"[%@] ", keyword] : @"",
          request.error,
          request.url, request.requestHeaders, request.requestMethod, request.postBody,
          request.responseStatusCode, request.responseHeaders, request.responseString,
          request.username, request.password);
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


@end
