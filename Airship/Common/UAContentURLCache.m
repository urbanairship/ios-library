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

#import "UAContentURLCache.h"
#import "UAContentURLCache+Internal.h"
#import "UAGlobal.h"

@implementation UAContentURLCache

@synthesize contentDictionary;
@synthesize timestampDictionary;
@synthesize path;
@synthesize expirationInterval;

#pragma mark -
#pragma mark Object Lifecycle

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

- (void)dealloc {
    self.contentDictionary = nil;
    self.timestampDictionary = nil;
    self.path = nil;
    [super dealloc];
}


#pragma mark -
#pragma mark Persistent Storage
- (void)saveToDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionary];
    [serialized setObject:contentDictionary forKey:kUrlCacheContentDictonaryKey];
    [serialized setObject:timestampDictionary forKey:kUrlCacheTimestampDictionaryKey];
    if (![serialized writeToFile:path atomically:YES]) {
        NSLog(@"failed to serialize content url cache");
    };
}

- (void)readFromDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    [contentDictionary addEntriesFromDictionary:[serialized objectForKey:kUrlCacheContentDictonaryKey]];
    [timestampDictionary addEntriesFromDictionary:[serialized objectForKey:kUrlCacheTimestampDictionaryKey]];
}

#pragma mark -
#pragma mark Cache Methods

- (void)setContent:(NSURL *)contentURL forProductURL:(NSURL *)productURL withVersion:(NSNumber *)version {
    NSString *contentURLString = [contentURL absoluteString];
    NSString *cacheKey = [self compoundKeyFromURL:productURL andVersion:version];
    // Bail on malfomed keys
    if (!cacheKey) {
        return;
    }
    @try {
        [contentDictionary setObject:contentURLString forKey:cacheKey];
        UALOG(@"Caching %@ for key %@", contentURLString, cacheKey);
    }
    @catch (NSException *exception) {
        if (exception.name == NSInvalidArgumentException) {
            UALOG(@"Attempt to set nil object in contentDictionary in setContent:forProductURL:withVersion:");
            return; 
        }
        else {
            @throw exception;
        }
    }
    [timestampDictionary setObject:[NSNumber numberWithDouble:[[NSDate date]timeIntervalSince1970]]
                            forKey:cacheKey];
    [self saveToDisk];
}

- (NSString*)compoundKeyFromURL:(NSURL*)URL andVersion:(NSNumber*)version {
    if (!URL || !version)return nil;
    return [NSString stringWithFormat:@"%@%@%@", [version stringValue], kUrlCacheCompoundKeyDelimiter, [URL absoluteString]];
}

- (NSDictionary*)productURLAndVersionFromCompoundKey:(NSString *)compoundKey {
    // Key is in the format version, delimiter, key
    NSArray* split = [compoundKey componentsSeparatedByString:kUrlCacheCompoundKeyDelimiter];
    if ([split count] != 2) {
        return nil;
    }
    // check for nil or empty
    for (NSString* string in split) {
        if (!string || [string length] == 0) {
            return nil;
        }
    }
    UALOG(@"Compound key %@ split into %@", compoundKey, split);
    return [NSDictionary dictionaryWithObjects:split forKeys:[NSArray arrayWithObjects:kUrlCacheProductVersionKey, kUrlCacheProductURLKey, nil]];
}

- (NSURL *)contentForProductURL:(NSURL *)productURL withVersion:(NSNumber *)version {
    NSString *cacheKey = [self compoundKeyFromURL:productURL andVersion:version];
    NSString *contentURLString = [contentDictionary objectForKey:cacheKey];
    NSURL *content = [NSURL URLWithString:contentURLString];
    UALOG(@"Returning contentURL %@ for cacheKey %@", content, cacheKey);
    if (content) {
        NSNumber *num = [timestampDictionary objectForKey:cacheKey];
        if (num) {
            NSTimeInterval timestamp = [num doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (now - timestamp < expirationInterval) {
                return content;
            } else {
                UALOG(@"Cached entry for %@ with key %@ is expired, removing", productURL, cacheKey);
                [contentDictionary removeObjectForKey:cacheKey];
                [timestampDictionary removeObjectForKey:cacheKey];
            }
        }
    }
    
    return nil;
}

@end
