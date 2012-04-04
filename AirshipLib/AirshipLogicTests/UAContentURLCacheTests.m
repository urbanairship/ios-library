/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import <SenTestingKit/SenTestingKit.h>
#import "UAContentURLCache.h"
#import "UAContentURLCache+Internal.h"

@interface UAContentURLCacheTests : SenTestCase {
    UAContentURLCache *cache;
    NSString* testCachePath;
}
@end


@implementation UAContentURLCacheTests

- (void)setUp {
    testCachePath  = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"TestURLCache.plist"] retain];
    NSError *fileError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:testCachePath error:&fileError];
    if (fileError) {
        STAssertTrue(fileError.code == 4, @"File error occured in setup");
    }
    else {
        NSLog(@"FILE ERROR IN UA_CONTENT_URLCACHE_TESTS SETUP");
    }
    cache = [[UAContentURLCache alloc] initWithExpirationInterval:1800 withPath:testCachePath];
}

- (void)tearDown {
    RELEASE(cache);
    RELEASE(testCachePath);
}

// Test that the cache doesn't crash on NSInvalidArgumentException
- (void)testSetContentForProductURLThrowsExpected {
    // Test no exception on nil keys/objects
    STAssertNoThrowSpecificNamed([cache setContent:[NSURL URLWithString:@"cats"] forProductURL:nil withVersion:[NSNumber numberWithInt:1]], NSException, NSInvalidArgumentException,nil);
    STAssertNoThrowSpecificNamed([cache setContent:nil forProductURL:[NSURL URLWithString:@"cats"] withVersion:[NSNumber numberWithInt:1]], NSException, NSInvalidArgumentException,nil);
    // Test that other exceptions get thrown
    id mockDictionary = [OCMockObject niceMockForClass:[NSMutableDictionary class]];
    [[[mockDictionary stub] andThrow:[NSException exceptionWithName:@"random" reason:@"Test exception thown on setObject:ANY_POINTER" userInfo:nil]] setObject:[OCMArg any] forKey:[OCMArg any]];
    cache.contentDictionary = mockDictionary;
    STAssertThrowsSpecificNamed([cache setContent:nil forProductURL:[NSURL URLWithString:@"cats"] withVersion:[NSNumber numberWithInt:1]], NSException, @"random", @"This method should only catch NSInvalidArg exceptions");
}

- (void)testSetContentForProductURLWillNotSaveNilCacheKey {
    id partialCache = [OCMockObject partialMockForObject:cache];
    [[[partialCache stub] andReturn:nil] compoundKeyFromURL:[OCMArg any] andVersion:[OCMArg any]];
    id mockContentDictionary = [OCMockObject niceMockForClass:[NSMutableDictionary class]];
    cache.contentDictionary = mockContentDictionary;
    [[mockContentDictionary reject] setObject:[OCMArg any] forKey:[OCMArg any]];
    [cache setContent:[NSURL URLWithString:@"url"] forProductURL:[NSURL URLWithString:@"cats"] withVersion:[NSNumber numberWithInt:1]];
}

- (void)testCompoundKeyEncoding {
    NSURL *url = [NSURL URLWithString:@"http://cats.com"];
    NSNumber *version = [NSNumber numberWithInt:42];
    NSString *compoundKey = [cache compoundKeyFromURL:url andVersion:version];
    NSError *regexError = nil;
    // The regex adds pattern recognition, start and end of line, and no spaces
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^%@%@%@$", [version stringValue], kUrlCacheCompoundKeyDelimiter, [url absoluteString]] options:NSRegularExpressionAnchorsMatchLines error:&regexError];
    NSUInteger one = 1;
    STAssertEquals([regex numberOfMatchesInString:compoundKey options:0 range:NSMakeRange(0, [compoundKey length])], one,nil);
    STAssertNil([cache compoundKeyFromURL:nil andVersion:[NSNumber numberWithInt:42]],nil);
    STAssertNil([cache compoundKeyFromURL:url andVersion:nil],nil);
}

// This test is tightly coupled to the above test by virtue of using the compound key encoding function. Beware. 
- (void)testCompoundKeyDecoding {
    NSURL *testURL = [NSURL URLWithString:@"http://cats.com"];
    NSNumber *testVersion = [NSNumber numberWithInt:42];
    NSString* compoundKey = [cache compoundKeyFromURL:testURL andVersion:testVersion];
    NSDictionary *deconstructedKey = [cache productURLAndVersionFromCompoundKey:compoundKey];
    NSString *version = [deconstructedKey valueForKey:kUrlCacheProductVersionKey];
    STAssertNotNil(version,nil);
    STAssertTrue([version isEqualToString:[testVersion stringValue]],nil);
    NSString *URLAsString = [deconstructedKey valueForKey:kUrlCacheProductURLKey];
    STAssertNotNil(URLAsString,nil);
    STAssertTrue([[testURL absoluteString] isEqualToString:URLAsString], nil);
    STAssertNil([cache productURLAndVersionFromCompoundKey:@"cats"],nil);
    NSString *onlyVersion = [NSString stringWithFormat:@"1%@", kUrlCacheCompoundKeyDelimiter];
    NSString *onlyProduct = [NSString stringWithFormat:@"%@product", kUrlCacheCompoundKeyDelimiter];
    STAssertNil([cache productURLAndVersionFromCompoundKey:onlyVersion],nil);
    STAssertNil([cache productURLAndVersionFromCompoundKey:onlyProduct],nil);
}

- (void)testSetContentForProductURLWithVersionCachesAppropriately {
    NSURL *productURL = [NSURL URLWithString:@"http://google.com"];
    NSURL *contentURL = [NSURL URLWithString:@"http://cats.com"];
    NSNumber *version = [NSNumber numberWithInt:42];
    NSError *fileError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:testCachePath error:&fileError];
    NSLog(@"File error, no file error is ok %@", fileError);
    UAContentURLCache *local = [[[UAContentURLCache alloc] initWithExpirationInterval:360 withPath:testCachePath] autorelease];
    [local setContent:contentURL forProductURL:productURL withVersion:version];
    NSDictionary *onDisk = [NSDictionary dictionaryWithContentsOfFile:testCachePath];
    NSLog(@"onDisk %@", onDisk);
    NSDictionary *contentDictionary = [onDisk valueForKey:kUrlCacheContentDictonaryKey];
    NSDictionary *timestampDictionary = [onDisk valueForKey:kUrlCacheTimestampDictionaryKey];
    NSString *cacheKey = [cache compoundKeyFromURL:productURL andVersion:version];
    BOOL contentWasSaved = [[contentDictionary valueForKey:cacheKey] isEqualToString:[contentURL absoluteString]];
    STAssertTrue(contentWasSaved, @"Content should exist in dictionary");
    NSTimeInterval timestamp = [[timestampDictionary valueForKey:cacheKey] doubleValue];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    // Check for within a tenth of a second difference
    STAssertEqualsWithAccuracy(timestamp, now, 0.1, nil);
}

//2012-03-28 14:30:26.523 otest[14390:7b03] onDisk {
//content =     {
//    "42<-version_product->http://google.com" = "http://cats.com";
//};
//timestamps =     {
//    "42<-version_product->http://google.com" = "1332970226.513117";
//};
//}

-(void)testContentForProductURLWithVersionReturnsMatchingCacheValues {
    NSURL *prod1 = [NSURL URLWithString:@"product1"];
    NSURL *content1 = [NSURL URLWithString:@"content1"];
    NSNumber *version1 = [NSNumber numberWithInt:1];
    NSNumber *version2 = [NSNumber numberWithInt:2];
    [cache setContent:content1 forProductURL:prod1 withVersion:version1];
    UAContentURLCache *newCache = [[UAContentURLCache alloc] initWithExpirationInterval:360 withPath:testCachePath];
    // Should return matching content
    NSURL *cacheContent = [newCache contentForProductURL:prod1 withVersion:version1];
    STAssertTrue([content1 isEqual:cacheContent], nil);
    // Should return nil on matching product but different version
    STAssertNil([cache contentForProductURL:prod1 withVersion:version2], nil);
    // Should return nil on no match
    STAssertNil([newCache contentForProductURL:[NSURL URLWithString:@"cats"] withVersion:version1],nil);
}

-(void)testContentForProductURLReturnsNilOnExpired {
    NSURL *content = [NSURL URLWithString:@"cats"];
    NSURL *product = [NSURL URLWithString:@"product"];
    NSNumber *version1 = [NSNumber numberWithInt:1];
    // Write out a cache
    [cache setContent:content forProductURL:product withVersion:version1];
    NSString *cacheKey = [cache compoundKeyFromURL:product andVersion:version1];
    // Read it from disk
    NSMutableDictionary *onDisk = [NSMutableDictionary dictionaryWithContentsOfFile:testCachePath];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSMutableDictionary *timestamps = [onDisk valueForKey:kUrlCacheTimestampDictionaryKey];
    // Roll back the timestamp
    [timestamps setValue:[NSNumber numberWithDouble:(now - 100)] forKey:cacheKey];
    [onDisk writeToFile:testCachePath atomically:YES];
    UAContentURLCache *local = [UAContentURLCache cacheWithExpirationInterval:90 withPath:testCachePath];
    NSURL *cacheURL = [local contentForProductURL:product withVersion:version1];
    STAssertNil(cacheURL, @"Content should return nil, it is expired");
}




@end
