/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAHTTPConnection.h"
#import "UAGlobal.h"

#import "UA_Base64.h"
#import <zlib.h>

@implementation UAHTTPRequest

@synthesize url;
@synthesize HTTPMethod;
@synthesize headers;
@synthesize username;
@synthesize password;
@synthesize body;
@synthesize compressBody;
@synthesize userInfo;

+ (UAHTTPRequest *)requestWithURLString:(NSString *)urlString {
    return [[[UAHTTPRequest alloc] initWithURLString:urlString] autorelease];
}

- (id)initWithURLString:(NSString *)urlString {
    if ((self = [super init])) {
        url = [[NSURL URLWithString:urlString] retain];
        headers = [[NSMutableDictionary alloc] init];
        body = nil;
        self.HTTPMethod = @"GET";
    }
    return self;
}

- (void) dealloc {
    RELEASE_SAFELY(url);
    RELEASE_SAFELY(HTTPMethod);
    RELEASE_SAFELY(headers);
    RELEASE_SAFELY(username);
    RELEASE_SAFELY(password);
    RELEASE_SAFELY(body);
    RELEASE_SAFELY(userInfo);
    [super dealloc];
}

- (void)addRequestHeader:(NSString *)header value:(NSString *)value {
    [headers setValue:value forKey:header];
}

- (void)appendBodyData:(NSData *)data {
    if (body == nil) {
        body = [[NSMutableData alloc] init];
    }
    [body appendData:data];
}



@end

@interface UAHTTPConnection()
- (NSData *)gzipCompress:(NSData *)uncompressedData;
@end

@implementation UAHTTPConnection
@synthesize delegate;

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest {
    return [[[UAHTTPConnection alloc] initWithRequest:httpRequest] autorelease];
}

- (id)initWithRequest:(UAHTTPRequest *)httpRequest {
    if ((self = [self init])) {
        request = [httpRequest retain];
        urlConnection = nil;
        responseData = nil;
        urlResponse = nil;
    }
    return self;
}

- (void) dealloc {
    RELEASE_SAFELY(request);
    RELEASE_SAFELY(urlConnection);
    RELEASE_SAFELY(urlResponse);
    RELEASE_SAFELY(responseData);
    [super dealloc];
}

- (BOOL)start {
    if (urlConnection != nil) {
        UALOG(@"ERROR: UAHTTPConnection already started: %@", self);
        return NO;
    } else {
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:request.url];
        for (NSString *header in [request.headers allKeys]) {
            [urlRequest setValue:[request.headers valueForKey:header] forHTTPHeaderField:header];
        }
        
        [urlRequest setHTTPMethod:request.HTTPMethod];
        [urlRequest setHTTPShouldHandleCookies:NO];
        
        //Set Auth
        if (request.username && request.password) {
            NSString *toEncode = [NSString stringWithFormat:@"%@:%@", request.username, request.password];
            
            // base64 encode credentials
            NSString *authString = UA_base64EncodedStringFromData([toEncode dataUsingEncoding:NSUTF8StringEncoding]);
            
            // strip CRLF sequences
            authString = [authString stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
            
            // add Basic auth prefix
            authString = [NSString stringWithFormat: @"Basic %@", authString];
            
            // set header
            [urlRequest setValue:authString  forHTTPHeaderField:@"Authorization"];
        }
        
        
        if (request.body != nil) {
            
            NSData *body = request.body;
            
            if (request.compressBody) {
                
                body = [self gzipCompress:request.body]; //returns nil if compression fails
                if (body) {
                    [urlRequest setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
                    //UALOG(@"Sending compressed body. Original size: %d Compressed size: %d", [request.body length], [body length]);
                } else {
                    UALOG(@"Body compression failed.");
                }

            }
            
            [urlRequest setHTTPBody:body];
            
        }
        
		responseData = [[NSMutableData alloc] init];
        urlConnection = [[NSURLConnection connectionWithRequest:urlRequest delegate:self] retain];
        return YES;
    }
}

#pragma mark -
#pragma mark NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    RELEASE_SAFELY(urlResponse);
    urlResponse = [response retain];
    [responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (responseData) {
        [responseData appendData:data];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    UALOG(@"ERROR: connection %@ didFailWithError: %@", self, error);
    if (delegate && [delegate respondsToSelector:@selector(requestDidFail:)]) {
        [delegate requestDidFail:request];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (delegate) {
        [delegate requestDidSucceed:request response:urlResponse responseData:responseData];
    }
}

#pragma mark -
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
    strm.avail_in = [uncompressedData length];

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
        strm.avail_out = [compressed length] - strm.total_out;

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
