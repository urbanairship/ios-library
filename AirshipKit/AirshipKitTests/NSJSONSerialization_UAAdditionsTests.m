/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UABaseTest.h"

#import "NSJSONSerialization+UAAdditions.h"

@interface NSJSONSerialization_UAAdditionsTests : UABaseTest

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
    XCTAssertEqual(jsonString.floatValue, @"3.3".floatValue, @"method should accept NSNumbers as fragment objects");
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
