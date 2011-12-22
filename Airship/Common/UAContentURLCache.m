/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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

#import "UAContentURLCache.h"

@interface UAContentURLCache()

- (void)readFromDisk;
- (void)saveToDisk;

@end

@implementation UAContentURLCache

@synthesize contentDictionary;
@synthesize timestampDictionary;
@synthesize path;
@synthesize expirationInterval;

+ (UAContentURLCache *)cacheWithExpirationInterval:(NSTimeInterval)interval withPath:(NSString *)pathString {
    return [[[UAContentURLCache alloc] initWithExpirationInterval:interval withPath:pathString] autorelease];
}

- (id)initWithExpirationInterval:(NSTimeInterval)interval withPath:(NSString *)pathString{
    if (self = [super init]) {
        self.contentDictionary = [NSMutableDictionary dictionary];
        self.timestampDictionary = [NSMutableDictionary dictionary];
        self.path = pathString;
        self.expirationInterval = interval;
        
        [self readFromDisk];
    }
    
    return self;
}

- (void)saveToDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionary];
    [serialized setObject:contentDictionary forKey:@"content"];
    [serialized setObject:timestampDictionary forKey:@"timestamps"];
    if (![serialized writeToFile:path atomically:YES]) {
        NSLog(@"failed to serialize content url cache");
    };
}

- (void)readFromDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    [contentDictionary addEntriesFromDictionary:[serialized objectForKey:@"content"]];
    [timestampDictionary addEntriesFromDictionary:[serialized objectForKey:@"timestamps"]];
}

- (void)setContent:(NSURL *)contentURL forProductURL:(NSURL *)productURL {
    NSString *contentURLString = [contentURL absoluteString];
    NSString *productURLString = [productURL absoluteString];
    [contentDictionary setObject:contentURLString forKey:productURLString];
    [timestampDictionary setObject:[NSNumber numberWithDouble:
                                   [[NSDate date]timeIntervalSince1970]]
                           forKey:productURLString];
    [self saveToDisk];
}

- (NSURL *)contentForProductURL:(NSURL *)productURL {
    NSString *productURLString = [productURL absoluteString];
    NSString *contentURLString = [contentDictionary objectForKey:productURLString];
    
    NSURL *content = [NSURL URLWithString:contentURLString];
    
    if (content) {
        NSNumber *num = [timestampDictionary objectForKey:productURLString];
        if (num) {
            NSTimeInterval timestamp = [num doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (now - timestamp < expirationInterval) {
                return content;
            } else {
                NSLog(@"cached entry for %@ is expired, removing", productURL);
                [contentDictionary removeObjectForKey:productURLString];
                [timestampDictionary removeObjectForKey:productURLString];
            }
        }
    }
    
    return nil;
}

- (void)dealloc {
    self.contentDictionary = nil;
    self.timestampDictionary = nil;
    self.path = nil;
    [super dealloc];
}


@end
