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

#import <SenTestingKit/SenTestingKit.h>

#import "NSJSONSerialization+UAAdditions.h"

@interface NSJSONSerialization_UAAdditionsTests : SenTestCase

@end

@implementation NSJSONSerialization_UAAdditionsTests


- (void)testStringWithObject {
    NSDictionary *dictionary = @{@"stringKey":@"stringValue", @"intKey": @1};

    NSString *jsonString = [NSJSONSerialization stringWithObject:dictionary];

    STAssertEqualObjects(@"{\"stringKey\":\"stringValue\",\"intKey\":1}", jsonString, @"stringWithObject produceses unexepected json strings");
}

- (void)testStringWithNilObject {
    STAssertNil([NSJSONSerialization stringWithObject:nil], @"stringWithObject should return nil if the object is nil");
}

- (void)testobjectWithString {
    NSString *jsonString = @"{\"stringKey\":\"stringValue\",\"intKey\":1}";
    NSDictionary *jsonDictionary = [NSJSONSerialization objectWithString:jsonString];

    NSDictionary *expectedDictonary =@{@"stringKey":@"stringValue", @"intKey": @1};
    STAssertEqualObjects(expectedDictonary, jsonDictionary, @"objectWithString produceses unexepected json dictionaries");
}

- (void)testobjectWithInvalidString {
    NSString *jsonString = @"some invalid json string";
    STAssertNil([NSJSONSerialization objectWithString:jsonString], @"objectWithString should return nil for invalid json strings");
}

- (void)testobjectWithNilStringRaises {
   STAssertNil([NSJSONSerialization objectWithString:nil], @"objectWithString should return nil for invalid json strings");
}


@end
