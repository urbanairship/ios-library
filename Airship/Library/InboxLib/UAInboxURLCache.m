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

#import "UAGlobal.h"
#import "UAUtils.h"

/**
 * Private methods
 */
@interface UAInboxURLCache()

//get the locations for content and content type files
- (NSString *)getStoragePathForURL:(NSURL *)url;
- (NSString *)getStoragePathForContentTypeWithURL:(NSURL *)url;

//lookup methods
- (NSArray *)mimeTypeAndCharsetForContentType:(NSString *)contentType;
- (NSString *)resourceTypeForRequest:(NSURLRequest *)request;

//store content (after retrieved)
- (void)storeContent:(NSData *)content withURL:(NSURL *)url contentType:(NSString *)contentType;

//retrieve content (run in new thread)
- (void)populateCacheFor:(NSURLRequest*)req;
@end

@implementation UAInboxURLCache

@synthesize cacheDirectory;
@synthesize resourceTypes;

#pragma mark -
#pragma mark NSURLCache methods
- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path {
    if (self = [super initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:path]) {
        self.cacheDirectory = path;
        
        self.resourceTypes = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"image/png", @".png",
                              @"image/gif", @".gif",
                              @"image/jpeg", @".jpg",
                              @"image/jpeg", @".jpeg",
                              @"application/javascript", @".js",
                              @"text/css", @".css", 
                              @"text/html", @"body", nil];
    }
    return self;
}

- (void)dealloc {
    RELEASE_SAFELY(cacheDirectory);
    RELEASE_SAFELY(resourceTypes);
    [super dealloc];
}

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request {
    
    UALOG(@"storeCachedResponse for URL: %@", [request.URL absoluteString]);
    
    UALOG(@"storeCachedResponse: %@", cachedResponse);
    
    NSData *content = cachedResponse.data;
    [self storeContent:content withURL:request.URL contentType:cachedResponse.response.MIMEType];    
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    
    NSCachedURLResponse* cachedResponse = nil;
    
    NSString *resourceType = [self resourceTypeForRequest:request];
    
    
    
    if (!resourceType) {
        UALOG(@"IGNORE CACHE for %@", request);
    } else if ([[request allHTTPHeaderFields] objectForKey:@"Referer"]) {
        UALOG(@"Do not cache items with Referer= %@", [[request allHTTPHeaderFields] objectForKey:@"Referer"]);
    } else {
        
        
        
        //retrieve resource from cache or populate if needed
        NSString *contentPath = [self getStoragePathForURL:request.URL];
        NSString *contentTypePath = [self getStoragePathForContentTypeWithURL:request.URL];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:contentPath]) {
            //retrieve it
            NSData *content = [NSData dataWithContentsOfFile:contentPath];
            
            NSString *contentType = [NSString stringWithContentsOfFile:contentTypePath encoding:NSUTF8StringEncoding error:NULL];
            NSString *charset = nil;
            
            if(!contentType) {
                UALOG(@"cachedResponseForRequest: unable to fetch content type for %@", [request.URL absoluteString]);
                //if there was a problem pulling out the content type, try to set it by looking up the resource, using text/html as a last resort
                contentType = [resourceTypes objectForKey:resourceType]?:@"text/html";
                charset = @"utf-8";
            }
            
            //if the content type expresses a charset (e.g. text/html; charset=utf8;) we need to break it up
            //into separate arguments so UIWebView doesn't get confused
            else {
                NSArray *subTypes = [self mimeTypeAndCharsetForContentType:contentType];
                contentType = [subTypes objectAtIndex:0];
                if(subTypes.count > 1) {
                    charset = [subTypes objectAtIndex:1];
                }
            }
            
            NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:request.URL MIMEType:contentType
                                                    expectedContentLength:[content length]
                                                         textEncodingName:charset]
                                       autorelease];
            // TODO: BUG in URLCache framework, so can't autorelease cachedResponse here.
            cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response
                                                                      data:content];
        }
        
        //evidently, UIWebView only tries to cache the main request body through the shared URLCache,
        //though it appears to be doing some additional resource caching internally.  this won't make
        //much of a difference for UIWebview, but will ensure we can transparently retrieved the cached
        //URL by other means
        else {
            [NSThread detachNewThreadSelector:@selector(populateCacheFor:)
                                     toTarget:self withObject:request];
        } 
    }
    
    return cachedResponse;
}

#pragma mark -
#pragma mark Private, Custom Cache Methods

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

- (NSString *)resourceTypeForRequest:(NSURLRequest *)request {
    
    // could it just be this? default is already text/html so does body matter?
    // return [resourceTypes objectForKey:[request.URL.relativePath pathExtension]];
    
    NSArray *tokens = [request.URL.relativePath componentsSeparatedByString:@"/"];
    if (tokens == nil) {
        return nil;
    }

    NSString *lastToken = [tokens objectAtIndex:[tokens count]-1];
    NSString *resourceType;
    
    for (NSString *type in [resourceTypes allKeys]) {
        if ([lastToken rangeOfString:type].location != NSNotFound) {
            resourceType = [resourceTypes objectForKey:type];
            return resourceType;
        }
    }
    
    return nil;
}

- (void)populateCacheFor:(NSURLRequest*)req {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    UA_ASIHTTPRequest *request = [[[UA_ASIHTTPRequest alloc] initWithURL:req.URL] autorelease];
    request.timeOutSeconds = 60;
    request.requestMethod = @"GET";
    
    //piggyback on whatever authorization was set for the original NSURLRequest
    [request.requestHeaders setObject:[req.allHTTPHeaderFields objectForKey:@"Authorization"] forKey:@"Authorization"];
    
    [request startSynchronous];
        
    NSError *error = [request error];
    if (error) {
        UALOG(@"Cache not populated for %@, error: %@", req.URL, error);
    } else {
        NSDictionary *headers = request.responseHeaders;
        NSString *contentType = [headers valueForKey:@"Content-Type"];
        if(!contentType) {
            //default to text/html if none is provided
            contentType = @"text/html";
        }
        [self storeContent:request.responseData withURL:req.URL contentType:contentType];
    }
    
    [pool release];
}

@end
