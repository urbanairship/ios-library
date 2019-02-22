/* Copyright Urban Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship.h"
#import "UAInAppMessageManager.h"
#import "UAInAppMessageFullScreenAdapter.h"
#import "UAInAppMessageFullScreenStyle.h"

@interface UAInAppMessageFullScreenStyleTest : UABaseTest

@property (nonatomic, strong) id mockBundle;

@end

@implementation UAInAppMessageFullScreenStyleTest

- (void)setUp {
    [super setUp];

    self.mockBundle = [self mockForClass:[NSBundle class]];
    [[[self.mockBundle stub] andReturn:[NSBundle bundleForClass:[self class]]] mainBundle];
}

- (void)tearDown {
    [self.mockBundle stopMocking];
    [super tearDown];
}

- (void)testInvalidStyle {
    // Ensure that unknown/improperly formatted values don't crash the app
    XCTAssertNoThrow([UAInAppMessageFullScreenStyle styleWithContentsOfFile:@"Invalid-UAInAppMessageFullScreenStyle"], @"Parsing an invalid UAInAppMessageFullScreenStyle file should never result in an exception");
}

- (void)testValidStyle {
    XCTAssertNoThrow([UAInAppMessageFullScreenStyle styleWithContentsOfFile:@"Valid-UAInAppMessageFullScreenStyle"],
                     @"Parsing a valid UAMessageCenterDefaultStyle file should never result in an exception");

    UAInAppMessageFullScreenStyle *validStyle = [UAInAppMessageFullScreenStyle styleWithContentsOfFile:@"Valid-UAInAppMessageFullScreenStyle"];

    //Properties in the valid style plist should match what's set in the style
    XCTAssertEqualObjects(@"testDismissIconResourceName", validStyle.dismissIconResource);
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
    XCTAssertEqualObjects(@22, validStyle.buttonStyle.stackedButtonSpacing);
    XCTAssertEqualObjects(@23, validStyle.buttonStyle.separatedButtonSpacing);
    XCTAssertEqualObjects(@24, validStyle.buttonStyle.additionalPadding.top);
    XCTAssertEqualObjects(@25, validStyle.buttonStyle.additionalPadding.bottom);
    XCTAssertEqualObjects(@26, validStyle.buttonStyle.additionalPadding.leading);
    XCTAssertEqualObjects(@27, validStyle.buttonStyle.additionalPadding.trailing);
}

@end
