/* Copyright Airship and Contributors */


#import "UABaseTest.h"

@interface UADefaultValueTransformerTest : UABaseTest
@end

@implementation UADefaultValueTransformerTest

- (void)testUnsecureToSecureTransformer {
    if (@available(iOS 12.0, *)) {
        NSURL *neat = [NSURL URLWithString:@"neat"];
        NSDictionary *cool = @{@"neat" : neat};

        NSValueTransformer *unsecureTransformer = [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName];
        NSValueTransformer *secureTransformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];

        id unsecureWriteResult = [unsecureTransformer reverseTransformedValue:cool];
        id secureReadResult = [secureTransformer transformedValue:unsecureWriteResult];

        XCTAssertEqualObjects(cool, secureReadResult);
    }
}

- (void)testSecureUnsecureTransformer {
    if (@available(iOS 12.0, *)) {
        NSURL *neat = [NSURL URLWithString:@"neat"];
        NSDictionary *cool = @{@"neat" : neat};

        NSValueTransformer *secureTransformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
        NSValueTransformer *unsecureTransformer = [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName];

        id secureWriteResult = [secureTransformer reverseTransformedValue:cool];
        id unsecureReadResult = [unsecureTransformer transformedValue:secureWriteResult];

        XCTAssertEqualObjects(cool, unsecureReadResult);
    }
}

- (void)testSecureAndUnsecureTransformerEqualBytes {
    if (@available(iOS 12.0, *)) {
        NSURL *neat = [NSURL URLWithString:@"neat"];
        NSDictionary *cool = @{@"neat" : neat};

        NSValueTransformer *secureTransformer = [NSValueTransformer valueTransformerForName:NSSecureUnarchiveFromDataTransformerName];
        NSValueTransformer *unsecureTransformer = [NSValueTransformer valueTransformerForName:NSKeyedUnarchiveFromDataTransformerName];

        id secureWriteResult = [secureTransformer reverseTransformedValue:cool];
        id unsecureWriteResult = [unsecureTransformer reverseTransformedValue:cool];

        XCTAssertEqualObjects(secureWriteResult, unsecureWriteResult);
    }
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
