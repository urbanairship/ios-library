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

#import "UAInboxURLCache.h"
#import "UA_ASIHTTPRequest.h"
#import "UAInbox.h"
#import "UAUser.h"

@implementation UAInboxURLCache

@synthesize cacheDirectory;

- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path {
    if (self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        self.cacheDirectory = [paths objectAtIndex:0];
    }
    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(cacheDirectory);
    [super dealloc];
}

- (NSString *)getStoragePath:(NSURL *)url {
    NSString *result = [NSString stringWithFormat:@"%@/UAInboxCache%@", cacheDirectory, url.relativePath];
    if (url.query != nil) {
        result = [NSString stringWithFormat:@"%@?%@", result, url.query];
    }
    return result;
}

- (NSString *)getAbsolutePath:(NSURL *)url {
    NSArray *tokens = [url.relativePath componentsSeparatedByString:@"/"];
    NSString *pathWithoutRessourceName = @"";
    for (int i = 0; i < [tokens count]-1; i++) {
        pathWithoutRessourceName = [pathWithoutRessourceName stringByAppendingString:[NSString stringWithFormat:@"%@%@", [tokens objectAtIndex:i], @"/"]];
    }
    return [NSString stringWithFormat:@"%@/UAInboxCache%@", cacheDirectory, pathWithoutRessourceName];
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request {
    UALOG(@"storeCachedResponse: %@", cachedResponse);
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    NSArray* tokens = [request.URL.relativePath componentsSeparatedByString:@"/"];
    if (tokens == nil) {
        UALOG(@"IGNORE CACHE for %@", request);
        return nil;
    }
    NSString* absolutePath = [self getAbsolutePath:request.URL];
    NSString* absolutePathWithResourceName = [NSString stringWithFormat:@"%@%@", cacheDirectory, request.URL.relativePath];
    NSString* resourceName = [absolutePathWithResourceName stringByReplacingOccurrencesOfString:absolutePath withString:@""];
    NSCachedURLResponse* cachedResponse = nil;
    if (
        [resourceName rangeOfString:@".png"].location!=NSNotFound ||
        [resourceName rangeOfString:@".gif"].location!=NSNotFound ||
        [resourceName rangeOfString:@".jpg"].location!=NSNotFound ||
        [resourceName rangeOfString:@".js"].location!=NSNotFound ||
        [resourceName rangeOfString:@".css"].location!=NSNotFound ||
        [resourceName rangeOfString:@"body"].location!=NSNotFound //This is for message content
        ) {
        NSString* storagePath = [self getStoragePath:request.URL];
        NSData* content;
        if ([[NSFileManager defaultManager] fileExistsAtPath:storagePath]) {
            UALOG(@"CACHE FOUND at %@", storagePath);
            content = [NSData dataWithContentsOfFile:storagePath];
            NSURLResponse* response = [[[NSURLResponse alloc] initWithURL:request.URL MIMEType:@"text/html"
                                                    expectedContentLength:[content length]
                                                         textEncodingName:nil]
                                       autorelease];
            // TODO: BUG in URLCache framework, so can't autorelease cachedResponse here.
            cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response
                                                                      data:content];
        } else {
            if ([resourceName rangeOfString:@"body"].location == NSNotFound) {
                [NSThread detachNewThreadSelector:@selector(populateCacheFor:)
                                         toTarget:self withObject:request];
            } else {
                [NSThread detachNewThreadSelector:@selector(populateAuthNeededCacheFor:)
                                         toTarget:self withObject:request];
            }
        }
    } else {
        UALOG(@"IGNORE CACHE for %@", request);
    }
    return cachedResponse;
}

- (void)populateAuthNeededCacheFor:(NSURLRequest*)req {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    UA_ASIHTTPRequest *request = [[[UA_ASIHTTPRequest alloc] initWithURL:req.URL] autorelease];
    request.timeOutSeconds = 60;
    request.username = [UAUser defaultUser].username;
    request.password = [UAUser defaultUser].password;
    request.requestMethod = @"GET";
    [request startSynchronous];

    NSError *error = [request error];
    if (error) {
        UALOG(@"Cache not populated for %@, error: %@", req.URL, error);
    } else {
        [self saveContentIfNecessary:request.responseData forRequestURL:req.URL];
    }

    [pool release];
}

- (void)populateCacheFor:(NSURLRequest*)request {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSData *content;
    NSError *error = nil;
    content = [NSData dataWithContentsOfURL:request.URL options:1 error:&error];
    if (error != nil) {
        UALOG(@"Cache not populated for %@, error: %@", request.URL, error);
    } else {
        [self saveContentIfNecessary:content forRequestURL:request.URL];
    }

    [pool release];
}

- (void)saveContentIfNecessary:(NSData *)content forRequestURL:(NSURL *)url {
    NSString* absolutePath = [self getAbsolutePath:url];
    NSString* storagePath = [self getStoragePath:url];
    if ([[NSFileManager defaultManager] fileExistsAtPath:storagePath]) {
        UALOG(@"File exists %@", storagePath);
    } else {
        [[NSFileManager defaultManager] createDirectoryAtPath:absolutePath
                                  withIntermediateDirectories:YES attributes:nil error:nil];
        BOOL ok = [content writeToFile:storagePath atomically:YES];
        UALOG(@"Caching %@ : %@", storagePath , ok?@"OK":@"FAILED");
    }
}

@end
