/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UAURLProtocol.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAHTTPRequest.H"
#import "UAHTTPConnection.h"
#import "UAirship.h"
#import "UAConfig.h"


@interface UAURLProtocol()

@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UAURLProtocol

static NSMutableOrderedSet *cachableURLs = nil;
static NSURLCache *cache = nil;


+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // The following conditions will return NO:
    // If the request header field contains kUASkipProtocolHeader
    // If the request HTTPMethod is not 'GET'
    // If the request URL scheme is not 'http' or 'https'
    if ([request valueForHTTPHeaderField:kUASkipProtocolHeader] || ![request.HTTPMethod isEqual:@"GET"]
        || !([[[request.URL scheme] lowercaseString] isEqualToString:@"http"] ||
             [[[request.URL scheme] lowercaseString] isEqualToString:@"https"])) {
        return NO;
    }

    return [[self cachableURLs] containsObject:request.URL]
            || [[self cachableURLs] containsObject:request.mainDocumentURL];

}

+ (NSMutableOrderedSet *)cachableURLs {
    @synchronized(self) {
        if (!cachableURLs) {
            cachableURLs = [NSMutableOrderedSet orderedSet];
        }
    }

    return cachableURLs;
}

+ (NSURLCache *)cache {
    @synchronized(self) {
        if (!cache) {

            NSString *diskCachePath = nil;
            NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            if ([cachePaths count]) {
                NSString *cacheDirectory = [cachePaths objectAtIndex:0];
                diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAURLCache"];

                [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                          withIntermediateDirectories:YES
                                                           attributes:nil error:NULL];
            }

            cache = [[NSURLCache alloc] initWithMemoryCapacity:kUACacheMemorySizeInMB
                                                  diskCapacity:[UAirship shared].config.cacheDiskSizeInMB
                                                      diskPath:diskCachePath];
        }
    }

    return cache;
}

+ (void)clearCache {
    [[self cache] removeAllCachedResponses];
}

+ (void)addCachableURL:(NSURL *)url {
    [[self cachableURLs] addObject:url];
}

+ (void)removeCachableURL:(NSURL *)url {
    [[self cachableURLs] removeObject:url];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    __weak UAURLProtocol *weakSelf = self;

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Received %ld for request %@.", (long)[request.response statusCode], request.url);

        // 200, cache response
        if ([request.response statusCode] == 200) {
            UA_LTRACE(@"Caching response.");
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc]initWithResponse:request.response
                                                                                          data:request.responseData];
            [[UAURLProtocol cache] storeCachedResponse:cachedResponse forRequest:weakSelf.request];

            [weakSelf finishRequest:request.response responseData:request.responseData];
        } else if (![weakSelf loadFromCache]) {
            [weakSelf finishRequest:request.response responseData:request.responseData];
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Error %@ for request %@, attempting to fall back to cache.", request.error, request.url);
        if (![weakSelf loadFromCache]) {
            [weakSelf finishRequest];
        }
    };

    self.connection = [UAHTTPConnection connectionWithRequest:[self createUAHTTPRequest]
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];

    [self.connection start];
}

- (void)stopLoading {
    [self.connection cancel];
}

- (BOOL)loadFromCache {
    NSCachedURLResponse *cachedResponse = [[UAURLProtocol cache] cachedResponseForRequest:self.request];
    if (cachedResponse) {
         UA_LTRACE(@"Loading response from cache.");
        [self finishRequest:cachedResponse.response responseData:cachedResponse.data];
        return YES;
    }

    UA_LTRACE(@"No cache for response %@", self.request.URL);
    return NO;
}

- (void)finishRequest {
    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]];
}

- (void)finishRequest:(NSURLResponse *)response responseData:(NSData *)data {
    // NSURLCacheStorageNotAllowed - we handle the caching ourselves.
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (UAHTTPRequest *)createUAHTTPRequest {
    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:self.request.URL];

    for (NSString *header in [self.request allHTTPHeaderFields]) {
        [request addRequestHeader:header value:[self.request valueForHTTPHeaderField:header]];
    }

    NSHTTPURLResponse *cachedResponse = (NSHTTPURLResponse *)[[UAURLProtocol cache] cachedResponseForRequest:self.request].response;
    if (cachedResponse) {
        NSString *cachedDate = [[cachedResponse allHeaderFields] valueForKey:@"Date"];
        [request addRequestHeader:@"If-Modified-Since" value:cachedDate];

        UA_LTRACE(@"Request %@ previously cached %@", request.url, cachedDate);
    }

    // Add a special header to tell our protocol to ignore it so a different
    // protocol will handle the request.
    [request addRequestHeader:kUASkipProtocolHeader value:@""];

    return request;
}

@end
