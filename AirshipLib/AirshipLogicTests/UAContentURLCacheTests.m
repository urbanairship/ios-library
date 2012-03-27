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

#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>
#import "UAContentURLCache.h"
#import <SenTestingKit/SenTestingKit.h>

@interface UAContentURLCacheTests : SenTestCase {
    UAContentURLCache *cache;
    
}
@end


@implementation UAContentURLCacheTests

- (void)setUp {
    NSString *cachePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TestURLCache.plist"];
    cache = [[UAContentURLCache alloc] initWithExpirationInterval:1800 withPath:cachePath];
}

- (void)tearDown {
    RELEASE(cache);
}

- (void)testSetContentForProductURL {
    // Test no exception on nil keys/objects
    STAssertNoThrowSpecificNamed([cache setContent:[NSURL URLWithString:@"cats"] forProductURL:nil], NSException, NSInvalidArgumentException,nil);
    STAssertNoThrowSpecificNamed([cache setContent:nil forProductURL:[NSURL URLWithString:@"cats"]], NSException, NSInvalidArgumentException,nil);
    id mockDictionary = [OCMockObject niceMockForClass:[NSMutableDictionary class]];
    [[[mockDictionary stub] andThrow:[NSException exceptionWithName:@"random" reason:@"too break stuff" userInfo:nil]] setObject:[OCMArg any] forKey:[OCMArg any]];
    cache.contentDictionary = mockDictionary;
    STAssertThrowsSpecificNamed([cache setContent:nil forProductURL:[NSURL URLWithString:@"cats"]], NSException, @"random", @"This method should only catch NSInvalidArg exceptions");
}



@end
