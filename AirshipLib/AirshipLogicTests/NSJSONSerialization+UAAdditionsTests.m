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

- (void)testobjectWithString {
    NSString *jsonString = @"{\"stringKey\":\"stringValue\",\"intKey\":1}";
    NSDictionary *jsonDictionary = [NSJSONSerialization objectWithString:jsonString];

    NSDictionary *expectedDictonary =@{@"stringKey":@"stringValue", @"intKey": @1};
    STAssertEqualObjects(expectedDictonary, jsonDictionary, @"objectWithString produceses unexepected json dictionaries");
}


@end
