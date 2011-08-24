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
#import "UAInbox.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"

@implementation UAInboxURLCache

@synthesize cacheDirectory;
@synthesize resourceTypes;

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
        
        NSError *error;
        ok = [contentType writeToFile:contentTypePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        UALOG(@"Caching %@ at %@: %@", [url absoluteString], contentTypePath, ok?@"OK":@"FAILED");
        
        if(error) {
            UALOG(@"storeContent: %@", error.localizedDescription);
        }
    }
} 

- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request {
    
    UALOG(@"storeCachedResponse: %@", cachedResponse);
    
    NSData *content = cachedResponse.data;
    [self storeContent:content withURL:request.URL contentType:cachedResponse.response.MIMEType];    
}

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    
    NSCachedURLResponse* cachedResponse;
    
    //not sure what this is accomplishing, but leaving it in for now
    NSArray* tokens = [request.URL.relativePath componentsSeparatedByString:@"/"];
    if (tokens == nil) {
        UALOG(@"IGNORE CACHE for %@", request);
        return nil;
    }
    
    NSString *resourceName = [tokens objectAtIndex:[tokens count]-1];
    
    BOOL ignoreCache = YES;
    
    for (NSString *type in [resourceTypes allKeys]) {
        if ([resourceName rangeOfString:type].location != NSNotFound) {
            ignoreCache = NO;
            break;
        }
    }
    
    if (ignoreCache) {
        UALOG(@"IGNORE CACHE for %@", request);
    }
        
    else {
        //retrieve resource from cache or populate if needed
        
        NSString *contentPath = [self getStoragePathForURL:request.URL];
        NSString *contentTypePath = [self getStoragePathForContentTypeWithURL:request.URL];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:contentPath]) {
            //retrieve it
            NSData *content = [NSData dataWithContentsOfFile:contentPath];
            
            NSError *error;
            NSString *contentType = [NSString stringWithContentsOfFile:contentTypePath encoding:NSUTF8StringEncoding error:&error];
            
            if(error) {
                UALOG(@"cachedResponseForRequest: %@", error.localizedDescription);
                //if there was a problem pulling out the content type, text/html is better than nothing
                contentType = @"text/html";
            }
            
            NSURLResponse* response = [[[NSURLResponse alloc] initWithURL:request.URL MIMEType:contentType
                                                    expectedContentLength:[content length]
                                                         textEncodingName:nil]
                                       autorelease];
            // TODO: BUG in URLCache framework, so can't autorelease cachedResponse here.
            cachedResponse = [[NSCachedURLResponse alloc] initWithResponse:response
                                                                      data:content];
        }
        
        //evidently, UIWebView only actively tries to cache the main request body
        else {
            //anything that's not the message body
            if ([resourceName rangeOfString:@"body"].location == NSNotFound) {
                [NSThread detachNewThreadSelector:@selector(populateCacheFor:)
                                         toTarget:self withObject:request];
            } 
            
            //this probably won't be called since we're using storeCachedResponse above, but leaving it for now
            else {
                [NSThread detachNewThreadSelector:@selector(populateAuthNeededCacheFor:)
                                         toTarget:self withObject:request];
            }
        }
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
        NSDictionary *headers = request.responseHeaders;
        NSString *contentType = [headers valueForKey:@"Content-type"];
        [self storeContent:request.responseData withURL:req.URL contentType:contentType];
    }

    [pool release];
}

- (void)populateCacheFor:(NSURLRequest*)req {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    UA_ASIHTTPRequest *request = [[[UA_ASIHTTPRequest alloc] initWithURL:req.URL] autorelease];
    request.timeOutSeconds = 60;
    request.requestMethod = @"GET";
    [request startSynchronous];
    
    NSError *error = [request error];
    if (error) {
        UALOG(@"Cache not populated for %@, error: %@", req.URL, error);
    } else {
        NSDictionary *headers = request.responseHeaders;
        NSString *contentType = [headers valueForKey:@"Content-type"];
        [self storeContent:request.responseData withURL:req.URL contentType:contentType];
    }
    
    [pool release];
}

@end
