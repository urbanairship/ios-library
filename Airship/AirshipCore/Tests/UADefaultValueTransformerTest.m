/* Copyright Airship and Contributors */


#import "UABaseTest.h"

@interface UADefaultValueTransformerTest : UABaseTest
@end

@implementation UADefaultValueTransformerTest

// Test that
- (void)testUnsecureToSecureTransformer {
    NSURL *neat = [NSURL URLWithString:@"neat"];
    NSDictionary *cool = @{@"neat" : neat};

    NSValueTransformer *unsecureTransformer = [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSValueTransformer *secureTransformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
#pragma GCC diagnostic pop

    id unsecureWriteResult = [unsecureTransformer reverseTransformedValue:cool];
    id secureReadResult = [secureTransformer transformedValue:unsecureWriteResult];

    XCTAssertEqualObjects(cool, secureReadResult);
}

- (void)testSecureUnsecureTransformer {
    NSURL *neat = [NSURL URLWithString:@"neat"];
    NSDictionary *cool = @{@"neat" : neat};

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    NSValueTransformer *secureTransformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
#pragma GCC diagnostic pop
    NSValueTransformer *unsecureTransformer = [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName];

    id secureWriteResult = [secureTransformer reverseTransformedValue:cool];
    id unsecureReadResult = [unsecureTransformer transformedValue:secureWriteResult];

    XCTAssertEqualObjects(cool, unsecureReadResult);
}

- (void)testDefaultValueTransformer {
    NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:@"UADefaultValueTransformerName"];
    XCTAssertNotNil(transformer);
    if (@available(iOS 12.0, *)) {
        XCTAssertEqualObjects(transformer, [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName]);
    } else {
        XCTAssertEqualObjects(transformer, [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName]);
    }
}

@end
