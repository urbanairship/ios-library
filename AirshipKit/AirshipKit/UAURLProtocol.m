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

#import "UAURLProtocol.h"
#import "UAirship.h"
#import "UAConfig.h"

@interface UAURLProtocol()
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@end

@implementation UAURLProtocol

static NSMutableSet *cachableURLs_ = nil;
static NSURLCache *cache_ = nil;

+ (void) load {
    cachableURLs_ = [NSMutableSet set];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // Reject non GET requests
    if (![request.HTTPMethod isEqualToString:@"GET"]) {
        return NO;
    }

    // Reject any non HTTP or HTTPS requests
    if (![request.URL.scheme isEqualToString:@"http"] && ![request.URL.scheme isEqualToString:@"https"]) {
        return NO;
    }

    // Make sure its cachabable URL
    return [[self cachableURLs] containsObject:request.URL] || [[self cachableURLs] containsObject:request.mainDocumentURL];
}

+ (NSMutableSet *)cachableURLs {
    return cachableURLs_;
}

+ (NSURLCache *)cache {
    static dispatch_once_t onceToken_;
    dispatch_once(&onceToken_, ^{
        cache_ = [[NSURLCache alloc] initWithMemoryCapacity:kUACacheMemorySizeInBytes
                                               diskCapacity:[UAirship shared].config.cacheDiskSizeInMB * 1024 * 1024
                                                   diskPath:@"UAURLCache"];
    });

    return cache_;
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

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.URLCache = [UAURLProtocol cache];
    config.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    self.dataTask = [session dataTaskWithRequest:self.request
                           completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

                               UAURLProtocol *strongSelf = weakSelf;

                               if (error) {
                                   // Try to force it to load from cache
                                   if (![self loadFromCache]) {
                                       [strongSelf.client URLProtocol:strongSelf didFailWithError:error];
                                   }

                                   return;
                               }

                               [self finishRequestWithResponse:response responseData:data];
                           }];

    [self.dataTask resume];
}

- (void)stopLoading {
    [self.dataTask cancel];
}

- (BOOL)loadFromCache {
    NSCachedURLResponse *cachedResponse = [[UAURLProtocol cache] cachedResponseForRequest:self.request];
    if (cachedResponse) {
        UA_LTRACE(@"Loading response from cache.");
        [self finishRequestWithResponse:cachedResponse.response responseData:cachedResponse.data];
        return YES;
    }

    return NO;
}

- (void)finishRequestWithResponse:(NSURLResponse *)response responseData:(NSData *)data {
    // NSURLCacheStorageNotAllowed - we handle the caching
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

@end
