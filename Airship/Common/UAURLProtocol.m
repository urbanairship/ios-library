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


@interface UAURLProtocol()

@property(nonatomic, strong) UAHTTPConnection *connection;

@end

@implementation UAURLProtocol

static NSMutableOrderedSet *cachableURLs = nil;
static NSURLCache *cache = nil;


+ (BOOL)canInitWithRequest:(NSURLRequest *)request {

    if ([request valueForHTTPHeaderField:UA_SKIP_PROTOCOL_HEADER] || ![request.HTTPMethod isEqual:@"GET"]) {
        return false;
    }

    return [[self cachableURLs] containsObject:request.URL]
            || [[self cachableURLs] containsObject:request.mainDocumentURL];

}

+ (NSMutableOrderedSet *)cachableURLs {
    if (!cachableURLs) {
        cachableURLs = [NSMutableOrderedSet orderedSet];
    }
    return cachableURLs;
}

+ (NSURLCache *)cache {
    if (!cache) {
        NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cachePaths objectAtIndex:0];
        NSString *diskCachePath = [NSString stringWithFormat:@"%@/%@", cacheDirectory, @"UAURLCache"];
        NSError *error;

        [[NSFileManager defaultManager] createDirectoryAtPath:diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:&error];

        cache = [[NSURLCache alloc] initWithMemoryCapacity:UA_PROTOCOL_MEMORY_CACHE_SIZE
                                              diskCapacity:UA_PROTOCOL_DISK_CACHE_SIZE
                                                  diskPath:diskCachePath];
    }
    return cache;
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
    __weak UAURLProtocol *_self = self;

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Received %ld for request %@.", (long)[request.response statusCode], request.url);

       if ([request.response statusCode] == 304) {
           UA_LTRACE(@"Loading response from cache.");
           [_self loadFromCache];
        } else {
            UA_LTRACE(@"Caching response.");
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc]initWithResponse:request.response
                                                                                          data:request.responseData];

            [[UAURLProtocol cache] storeCachedResponse:cachedResponse forRequest:_self.request];

            [_self finishRequest:request.response responseData:request.responseData];
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        UA_LTRACE(@"Error %@ for request %@, attempting to fall back to cache.", request.error, request.url);
        [_self loadFromCache];
    };

    self.connection = [UAHTTPConnection connectionWithRequest:[self createUAHTTPRequest]
                                                 successBlock:successBlock
                                                 failureBlock:failureBlock];

    [self.connection start];
}

- (void)stopLoading {
    [self.connection cancel];
}

- (void)loadFromCache {
    NSCachedURLResponse *cachedResponse = [[UAURLProtocol cache] cachedResponseForRequest:self.request];
    if (cachedResponse) {
        [self finishRequest:cachedResponse.response responseData:cachedResponse.data];
    } else {
        UA_LTRACE(@"No cache for response %@", self.request.URL);

        [self finishRequest];
    }
}

- (void)finishRequest {
    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]];
}

- (void)finishRequest:(NSURLResponse *)response responseData:(NSData *)data {
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
    [request addRequestHeader:UA_SKIP_PROTOCOL_HEADER value:@"true"];

    return request;
}

@end
