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

#import "UAGlobal.h"
#import "UAUtils.h"
#import "UAirship.h"

/**
 * Private methods
 */
@interface UAInboxURLCache()

//get the locations for content and content type files
- (NSString *)getStoragePathForURL:(NSURL *)url;
- (NSString *)getStoragePathForContentTypeWithURL:(NSURL *)url;

//lookup methods
- (NSArray *)mimeTypeAndCharsetForContentType:(NSString *)contentType;

//store content on disk
- (void)storeContent:(NSData *)content withURL:(NSURL *)url contentType:(NSString *)contentType;

- (BOOL)shouldStoreCachedResponse:(NSCachedURLResponse *)response forRequest:(NSURLRequest *)request;

@end

@implementation UAInboxURLCache

@synthesize cacheDirectory;
@synthesize resourceTypes;

#pragma mark -
#pragma mark NSURLCache methods
- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path {
    if (self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path]) {
        self.cacheDirectory = path;

        self.resourceTypes = [NSArray arrayWithObjects:
                              @"image/png", @"image/gif", @"image/jpg", @"text/javascript", @"application/javascript", @"text/css", nil];
    }
    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(cacheDirectory);
    RELEASE_SAFELY(resourceTypes);
    [super dealloc];
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request {
    
    if ([self shouldStoreCachedResponse:cachedResponse forRequest:request]) {
        
        UALOG(@"storeCachedResponse for URL: %@", [request.URL absoluteString]);
        UALOG(@"storeCachedResponse: %@", cachedResponse);
        
        NSData *content = cachedResponse.data;
        
        //default to "text/html" if the server doesn't provide a content type
        NSString *contentType = cachedResponse.response.MIMEType?:@"text/html";
        
        [self storeContent:content withURL:request.URL contentType:contentType];
    }
    
    else {
        UALOG(@"IGNORE CACHE for %@", request);
    }
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    
    NSCachedURLResponse* cachedResponse = nil;
    
    //retrieve resource from cache or populate if needed
    NSString *contentPath = [self getStoragePathForURL:request.URL];
    NSString *contentTypePath = [self getStoragePathForContentTypeWithURL:request.URL];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:contentPath]) {
        //retrieve it
        NSData *content = [NSData dataWithContentsOfFile:contentPath];
        
        NSString *contentType = [NSString stringWithContentsOfFile:contentTypePath 
                                                          encoding:NSUTF8StringEncoding 
                                                             error:NULL];
        NSString *charset = nil;
        
        //if the content type expresses a charset (e.g. text/html; charset=utf8;) we need to break it up
        //into separate arguments so UIWebView doesn't get confused
        NSArray *subTypes = [self mimeTypeAndCharsetForContentType:contentType];
        contentType = [subTypes objectAtIndex:0];
        if(subTypes.count > 1) {
            charset = [subTypes objectAtIndex:1];
        }
        
        NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:request.URL MIMEType:contentType
                                                expectedContentLength:[content length]
                                                     textEncodingName:charset]
                                   autorelease];
        // TODO: BUG in URLCache framework, so can't autorelease cachedResponse here.
        cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response
                                                                  data:content];
        
        UALOG(@"Uncaching request %@", request);
    }
    
    return cachedResponse;
}

#pragma mark -
#pragma mark Private, Custom Cache Methods

- (BOOL)shouldStoreCachedResponse:(NSCachedURLResponse *)response forRequest:(NSURLRequest *)request {
    
    NSString *referer = [[request allHTTPHeaderFields] objectForKey:@"Referer"];
    BOOL whitelisted = [resourceTypes containsObject:response.response.MIMEType];
    NSString *host = request.URL.host;
    NSString  *airshipHost = [[NSURL URLWithString:[UAirship shared].server] host];
    
    //only cache responses to requests for content from the airship server, 
    //or content types in the whitelist with no referer
    
    return [airshipHost isEqualToString:host] || (whitelisted && !referer);
}

- (NSString *)getStoragePathForURL:(NSURL *)url {    
    NSString *hashedURLString = [UAUtils md5:[url absoluteString]];
    return [NSString stringWithFormat:@"%@/%@", cacheDirectory, hashedURLString];
}

- (NSString *)getStoragePathForContentTypeWithURL:(NSURL *)url {
    return [NSString stringWithFormat:@"%@%@", [self getStoragePathForURL:url], @".contentType"];
}

- (void)storeContent:(NSData *)content withURL:(NSURL *)url contentType:(NSString *)contentType {
    
    NSString *contentPath = [self getStoragePathForURL:url];
    NSString *contentTypePath = [self getStoragePathForContentTypeWithURL:url];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:contentPath]) {
        UALOG(@"File exists %@", contentPath);
    }
    
    else {
        BOOL ok = [content writeToFile:contentPath atomically:YES];
        UALOG(@"Caching %@ at %@: %@", [url absoluteString], contentPath, ok?@"OK":@"FAILED");
        
        ok = [contentType writeToFile:contentTypePath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        UALOG(@"Caching %@ at %@: %@", contentType, contentTypePath, ok?@"OK":@"FAILED");
    }
}

- (NSArray *)mimeTypeAndCharsetForContentType:(NSString *)contentType {
   
    NSRange range = [contentType rangeOfString:@"charset="];
    
    NSString *contentSubType;
    NSString *charset;
    
    if (range.location != NSNotFound) {
        contentSubType = [[[contentType substringToIndex:range.location] stringByReplacingOccurrencesOfString:@";" withString:@""]
                     stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        charset = [[contentType substringFromIndex:(range.location + range.length)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        return [NSArray arrayWithObjects:contentSubType, charset, nil];
    }
    
    else {
        return [NSArray arrayWithObjects:contentType, nil];
    }    
}

@end
