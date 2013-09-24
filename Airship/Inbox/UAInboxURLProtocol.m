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

#import "UAInboxURLProtocol.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAHTTPRequest.H"
#import "UAHTTPConnection.h"



@implementation UAInboxURLProtocol

static NSMutableOrderedSet *cachableURLs = nil;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {

    if ([request valueForHTTPHeaderField:@"ua-skip-protocol"] || ![request.HTTPMethod isEqual:@"GET"]) {
        return false;
    }

    return [[self cachableURLs] containsObject:request.URL]
            || [[self cachableURLs] containsObject:request.mainDocumentURL];

}

- (void)startLoading {
    UAHTTPRequest *request = [UAHTTPRequest requestWithURL:self.request.URL];
    __weak UAInboxURLProtocol *_self = self;

    for (NSString *header in [self.request allHTTPHeaderFields]) {
        [request addRequestHeader:header value:[self.request valueForHTTPHeaderField:header]];
    }

    NSHTTPURLResponse *cachedResponse = (NSHTTPURLResponse *)[[UAInbox shared].cache cachedResponseForRequest:self.request].response;
    if (cachedResponse) {
        [request addRequestHeader:@"If-Modified-Since" value:[[cachedResponse allHeaderFields] valueForKey:@"Date"]];
    }

    [request addRequestHeader:@"ua-skip-protocol" value:@"true"];

    UAHTTPConnectionSuccessBlock successBlock = ^(UAHTTPRequest *request){
        if (request.error || [request.response statusCode] == 304) {
            [_self loadFromCache];
        } else {
            NSCachedURLResponse *cachedResponse = [[NSCachedURLResponse alloc]initWithResponse:request.response
                                                                                          data:request.responseData];

            [[UAInbox shared].cache storeCachedResponse:cachedResponse forRequest:_self.request];

            [self finishRequest:request.response responseData:request.responseData];
        }
    };

    UAHTTPConnectionFailureBlock failureBlock = ^(UAHTTPRequest *request){
        [_self loadFromCache];
    };


    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:request
                                                              successBlock:successBlock
                                                              failureBlock:failureBlock];

    [connection start];
}

- (void)stopLoading {

}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)loadFromCache {
    NSCachedURLResponse *cachedResponse = [[UAInbox shared].cache cachedResponseForRequest:self.request];
    if (cachedResponse) {
        [self finishRequest:cachedResponse.response responseData:cachedResponse.data];
    } else {
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

+(NSMutableOrderedSet *)cachableURLs {
    if (!cachableURLs) {
        cachableURLs = [NSMutableOrderedSet orderedSet];
    }
    return cachableURLs;
}

+(void)addCachableURL:(NSURL *)url {
    [[self cachableURLs] addObject:url];
}

+(void)removeCachableURL:(NSURL *)url {
    [[self cachableURLs] removeObject:url];
}

@end
