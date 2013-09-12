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

#import "UAHTTPConnection+Internal.h"
#import "UAHTTPRequest+Internal.h"

#import "UAGlobal.h"
#import "UAInboxURLCache.h"
#import "UA_Base64.h"
#import <zlib.h>



@implementation UAHTTPConnection


+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest {
    return [[[UAHTTPConnection alloc] initWithRequest:httpRequest] autorelease];
}

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest
                                   delegate:(id)delegate
                                    success:(SEL)successSelector
                                    failure:(SEL)failureSelector {
    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:httpRequest];
    connection.delegate = delegate;
    connection.successSelector = successSelector;
    connection.failureSelector = failureSelector;

    return connection;
}

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest
                               successBlock:(UAHTTPConnectionSuccessBlock)successBlock
                               failureBlock:(UAHTTPConnectionFailureBlock)failureBlock {
    UAHTTPConnection *connection = [UAHTTPConnection connectionWithRequest:httpRequest];
    connection.successBlock = successBlock;
    connection.failureBlock = failureBlock;

    return connection;
}

- (id)init {
    return [super init];
}

- (id)initWithRequest:(UAHTTPRequest *)httpRequest {
    self = [self init];
    if (self) {
        self.request = httpRequest;
    }
    return self;
}

- (void)dealloc {
    self.urlResponse = nil;
    self.urlConnection = nil;
    self.request = nil;
    self.responseData = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
    [super dealloc];
}

- (NSURLRequest *)buildRequest {
    if (self.urlConnection) {
        UA_LDEBUG(@"ERROR: UAHTTPConnection already started: %@", self);
        return nil;
    } else {

        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:_request.url];
        
        for (NSString *header in [_request.headers allKeys]) {
            [urlRequest setValue:[_request.headers valueForKey:header] forHTTPHeaderField:header];
        }

        [urlRequest setHTTPMethod:_request.HTTPMethod];
        [urlRequest setHTTPShouldHandleCookies:NO];

        //Set Auth
        if (_request.username && _request.password) {
            NSString *toEncode = [NSString stringWithFormat:@"%@:%@", _request.username, _request.password];

            // base64 encode credentials
            NSString *authString = UA_base64EncodedStringFromData([toEncode dataUsingEncoding:NSUTF8StringEncoding]);

            // strip CRLF sequences
            authString = [authString stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];

            // add Basic auth prefix
            authString = [NSString stringWithFormat: @"Basic %@", authString];

            // set header
            [urlRequest setValue:authString forHTTPHeaderField:@"Authorization"];
        }

        if (_request.body) {

            NSData *body = _request.body;

            if (_request.compressBody) {

                body = [self gzipCompress:_request.body]; //returns nil if compression fails
                if (body) {
                    [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
                    //UA_LDEBUG(@"Sending compressed body. Original size: %d Compressed size: %d", [request.body length], [body length]);
                } else {
                    UA_LDEBUG(@"Body compression failed.");
                }

            }

            [urlRequest setHTTPBody:body];

        }
        return urlRequest;
    }
}

- (BOOL)start {
    NSURLRequest *urlRequest = [self buildRequest];

    if (!urlRequest) {
        return NO;
    }

    // keep ourselves around for a while so the request can complete
    [self retain];

    self.responseData = [NSMutableData data];
    self.urlConnection = [NSURLConnection connectionWithRequest:urlRequest delegate:self];

    return YES;
}

- (BOOL)startSynchronous {
    NSURLRequest *urlRequest = [self buildRequest];

    if (!urlRequest) {
        return NO;
    }

    NSError *error = nil;

    self.responseData = [[[NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&_urlResponse error:&error] mutableCopy] autorelease];

    self.request.response = self.urlResponse;
    self.request.responseData = self.responseData;
    self.request.error = error;

    return !error;
}

- (void)cancel {
    [self.urlConnection cancel];
}

#pragma mark -
#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    self.urlResponse = response;
    [self.responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    UA_LDEBUG(@"ERROR: connection %@ didFailWithError: %@", self, error);
    self.request.error = error;
    if ([self.delegate respondsToSelector:self.failureSelector]) {
        [self.delegate performSelector:self.failureSelector withObject:_request];
    }

    if (self.failureBlock) {
        self.failureBlock(self.request);
    }
    
    self.failureBlock = nil;
    self.successBlock = nil;
    
    [self release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    
    self.request.response = self.urlResponse;
    self.request.responseData = self.responseData;
    
    if ([self.delegate respondsToSelector:self.successSelector]) {
        [self.delegate performSelector:self.successSelector withObject:self.request];
    }

    if (self.successBlock) {
        self.successBlock(self.request);
    }

    self.failureBlock = nil;
    self.successBlock = nil;
    
    [self release];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    if ([[NSURLCache sharedURLCache] isKindOfClass:[UAInboxURLCache class]]) {
        return nil;
    } else {
        return cachedResponse;
    }
}

#pragma mark GZIP compression

- (NSData *)gzipCompress:(NSData *)uncompressedData {

    if ([uncompressedData length] == 0) {
        return nil;
    }

    z_stream strm;
    
    int chunkSize = 32768;// 32K chunks
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)[uncompressedData bytes];
    strm.avail_in = (uInt)[uncompressedData length];

    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }
    
    int status;
    NSMutableData *compressed = [NSMutableData dataWithLength:chunkSize];
    do {

        if (strm.total_out >= [compressed length]) {
            [compressed increaseLengthBy: chunkSize];
        }

        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([compressed length] - strm.total_out);

        status = deflate(&strm, Z_FINISH);
        
        if (status == Z_STREAM_ERROR) {
            //error - bail completely
            deflateEnd(&strm);
            return nil;
        }
        
    } while (strm.avail_out == 0);

    deflateEnd(&strm);

    [compressed setLength: strm.total_out];
    
    return compressed;
}

@end
