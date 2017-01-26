/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import <XCTest/XCTest.h>

#import "NSJSONSerialization+UAAdditions.h"

@interface NSJSONSerialization_UAAdditionsTests : XCTestCase

@end

@implementation NSJSONSerialization_UAAdditionsTests


- (void)testStringWithObject {
    NSDictionary *dictionary = @{@"stringKey":@"stringValue", @"intKey": @1};

    NSString *jsonString = [NSJSONSerialization stringWithObject:dictionary];

    XCTAssertEqualObjects(@"{\"stringKey\":\"stringValue\",\"intKey\":1}", jsonString, @"stringWithObject produces unexpected json strings");
}

- (void)testStringWithStringObject {
    NSString *string = @"gosh folks, you sure look swell";
    NSString *jsonString = [NSJSONSerialization stringWithObject:string acceptingFragments:YES];
    XCTAssertEqualObjects(jsonString, @"\"gosh folks, you sure look swell\"", @"method should accept strings as fragment objects");
}

- (void)testStringWithNumberObject {
    NSString *jsonString = [NSJSONSerialization stringWithObject:[NSNumber numberWithFloat:3.3] acceptingFragments:YES];
    XCTAssertEqualObjects(jsonString, @"3.3", @"method should accept NSNumbers as fragment objects");
}

- (void)testStringWithNullObject {
    NSString *jsonString = [NSJSONSerialization stringWithObject:[NSNull null] acceptingFragments:YES];
    XCTAssertEqualObjects(jsonString, @"null", @"method should accept NSNulls as fragment objects");
}

- (void)testStringWithBoolObject {
    NSString *jsonString = [NSJSONSerialization stringWithObject:[NSNumber numberWithBool:YES] acceptingFragments:YES];
    XCTAssertEqualObjects(jsonString, @"true", @"method should accept bool NSNumbers as fragment objects, and convert to JSON boolean values");
}

- (void)testStringWithInvalidObject {
    NSError *error = nil;
    NSString *jsonString = [NSJSONSerialization stringWithObject:self error:&error];
    XCTAssertNil(jsonString, @"invalid (non-serializable) objects should result in a nil value");
    XCTAssertNotNil(error, @"invalid objects should result in an error");
    XCTAssertEqualObjects(error.domain, UAJSONSerializationErrorDomain, @"error domain should be UAJSONSerializationErrorDomain");
    XCTAssertEqual(error.code, UAJSONSerializationErrorCodeInvalidObject, @"error code should be UAJSONSerializationErrorCodeInvalidObject");
}

- (void)testobjectWithString {
    NSString *jsonString = @"{\"stringKey\":\"stringValue\",\"intKey\":1}";
    NSDictionary *jsonDictionary = [NSJSONSerialization objectWithString:jsonString];

    NSDictionary *expectedDictonary =@{@"stringKey":@"stringValue", @"intKey": @1};
    XCTAssertEqualObjects(expectedDictonary, jsonDictionary, @"objectWithString produces unexpected json dictionaries");
}

- (void)testobjectWithInvalidString {
    NSString *jsonString = @"some invalid json string";
    XCTAssertNil([NSJSONSerialization objectWithString:jsonString], @"objectWithString should return nil for invalid json strings");
}

@end
