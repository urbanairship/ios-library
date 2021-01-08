/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageBannerAdapter.h"
#import "UAInAppMessageBannerStyle.h"

@interface UAInAppMessageBannerStyleTest : UABaseTest

@property (nonatomic, strong) id mockBundle;

@end

@implementation UAInAppMessageBannerStyleTest

- (void)setUp {
    [super setUp];

    self.mockBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:[NSBundle bundleForClass:[self class]]] mainBundle];
}

- (void)testInvalidStyle {
    // Ensure that unknown/improperly formatted values don't crash the app
    XCTAssertNoThrow([UAInAppMessageBannerStyle styleWithContentsOfFile:@"Invalid-UAInAppMessageBannerStyle"], @"Parsing an invalid UAInAppMessageBannerStyle file should never result in an exception");
}

- (void)testValidStyle {
    XCTAssertNoThrow([UAInAppMessageBannerStyle styleWithContentsOfFile:@"Valid-UAInAppMessageBannerStyle"],
                     @"Parsing a valid UAMessageCenterDefaultStyle file should never result in an exception");

    UAInAppMessageBannerStyle *validStyle = [UAInAppMessageBannerStyle styleWithContentsOfFile:@"Valid-UAInAppMessageBannerStyle"];

    //Properties in the valid style plist should match what's set in the style
    XCTAssertEqualObjects(@1, validStyle.additionalPadding.top);
    XCTAssertEqualObjects(@2, validStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@3, validStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@4, validStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@5, validStyle.headerStyle.letterSpacing);
    XCTAssertEqualObjects(@6, validStyle.headerStyle.lineSpacing);
    XCTAssertEqualObjects(@7, validStyle.headerStyle.additionalPadding.top);
    XCTAssertEqualObjects(@8, validStyle.headerStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@9, validStyle.headerStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@10, validStyle.headerStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@11, validStyle.bodyStyle.letterSpacing);
    XCTAssertEqualObjects(@12, validStyle.bodyStyle.lineSpacing);
    XCTAssertEqualObjects(@13, validStyle.bodyStyle.additionalPadding.top);
    XCTAssertEqualObjects(@14, validStyle.bodyStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@15, validStyle.bodyStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@16, validStyle.bodyStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@17, validStyle.mediaStyle.additionalPadding.top);
    XCTAssertEqualObjects(@18, validStyle.mediaStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@19, validStyle.mediaStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@20, validStyle.mediaStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@21, validStyle.buttonStyle.buttonHeight);
    XCTAssertEqualObjects(@22, validStyle.buttonStyle.additionalPadding.top);
    XCTAssertEqualObjects(@23, validStyle.buttonStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@24, validStyle.buttonStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@25, validStyle.buttonStyle.additionalPadding.trailing);
    XCTAssertEqualObjects(@26, validStyle.maxWidth);
}

@end
