/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UAInAppMessageHTMLStyle.h"
@import AirshipCore;

@interface UAInAppMessageHTTMLStyleTest : UABaseTest
@property (nonatomic, strong) id mockBundle;
@end


@implementation UAInAppMessageHTTMLStyleTest

- (void)setUp {
    [super setUp];

    self.mockBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:[NSBundle bundleForClass:[self class]]] mainBundle];
}

- (void)testValidStyle {
    UAInAppMessageHTMLStyle *validStyle = [UAInAppMessageHTMLStyle styleWithContentsOfFile:@"Valid-UAInAppMessageHTMLStyle"];

    //Properties in the valid style plist should match what's set in the style
    XCTAssertEqualObjects(@"testDismissIconResourceName", validStyle.dismissIconResource);
    XCTAssertEqualObjects(@1, validStyle.additionalPadding.top);
    XCTAssertEqualObjects(@2, validStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@3, validStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@4, validStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@28, validStyle.maxWidth);
    XCTAssertEqualObjects(@29, validStyle.maxHeight);
    XCTAssertTrue(validStyle.hideDismissIcon);
}
@end
