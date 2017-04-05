/* Copyright 2017 Urban Airship and Contributors */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "UAirship.h"
#import "UADefaultMessageCenter.h"
#import "UADefaultMessageCenterStyle.h"
#import "UAColorUtils+Internal.h"

@interface UADefaultMessageCenterStyleTest : XCTestCase

@property (nonatomic, strong) id mockBundle;

@end

@implementation UADefaultMessageCenterStyleTest

- (void)setUp {
    self.mockBundle = [OCMockObject niceMockForClass:[NSBundle class]];
    //[[[self.mockBundle stub] andReturn:self.mockBundle] mainBundle];
    // Return class bundle instead of main bundle for tests
    [[[self.mockBundle stub] andReturn:[NSBundle bundleForClass:[self class]]] mainBundle];
}

- (void)tearDown {
    [self.mockBundle stopMocking];
}

// Just compare initial values to final value and return
- (void)testInvalidStyle {
    // Whatever is set in the xib (nil in this case)
    UADefaultMessageCenterStyle *defaultStyle = [[UADefaultMessageCenterStyle alloc] init];

    // ensure that unknown/improperly formatted values don't crash the app
    XCTAssertNoThrow([UADefaultMessageCenterStyle styleWithContentsOfFile:@"Invalid-UAMessageCenterDefaultStyle"], @"Parsing an invalid UAMessageCenterDefaultStyle file should never result in an exception" );

    UADefaultMessageCenterStyle *invalidStyle = [UADefaultMessageCenterStyle styleWithContentsOfFile:@"Invalid-UAMessageCenterDefaultStyle"];

    [UAirship defaultMessageCenter].style = invalidStyle;

    // the invalid style plist has one valid property - cellSeparatorColor, ensure this sets despite invalids
    XCTAssertNotNil(invalidStyle.cellSeparatorColor, @"cellSeparatorColor should be valid");

    // properties in the invalid style plist should not override the corresponding (nil) default style properties
    // (except cellSeparatorColor)
    XCTAssertEqualObjects(defaultStyle.titleFont, invalidStyle.titleFont);
    XCTAssertEqualObjects(defaultStyle.titleColor, invalidStyle.titleColor);
    XCTAssertEqualObjects(defaultStyle.tintColor, invalidStyle.tintColor);
    XCTAssertEqualObjects(defaultStyle.navigationBarColor, invalidStyle.navigationBarColor);

    // in this case the two should differ, since we are defaulting to a YES value in the style
    XCTAssertEqual(defaultStyle.navigationBarOpaque, invalidStyle.navigationBarOpaque);

    XCTAssertEqualObjects(defaultStyle.listColor, invalidStyle.listColor);
    XCTAssertEqualObjects(defaultStyle.refreshTintColor, invalidStyle.refreshTintColor);
    XCTAssertEqual(defaultStyle.iconsEnabled, invalidStyle.iconsEnabled);
    XCTAssertEqualObjects(defaultStyle.placeholderIcon, invalidStyle.placeholderIcon);
    XCTAssertEqualObjects(defaultStyle.cellTitleFont, invalidStyle.cellTitleFont);
    XCTAssertEqualObjects(defaultStyle.cellDateFont, invalidStyle.cellDateFont);
    XCTAssertEqualObjects(defaultStyle.cellColor, invalidStyle.cellColor);
    XCTAssertEqualObjects(defaultStyle.cellHighlightedColor, invalidStyle.cellHighlightedColor);
    XCTAssertEqualObjects(defaultStyle.cellTitleColor, invalidStyle.cellTitleColor);
    XCTAssertEqualObjects(defaultStyle.cellTitleHighlightedColor, invalidStyle.cellTitleHighlightedColor);
    XCTAssertEqualObjects(defaultStyle.cellDateColor, invalidStyle.cellDateColor);
    XCTAssertEqualObjects(defaultStyle.cellDateHighlightedColor, invalidStyle.cellDateHighlightedColor);
    XCTAssertEqualObjects(defaultStyle.cellTintColor, invalidStyle.cellTintColor);
    XCTAssertEqualObjects(defaultStyle.unreadIndicatorColor, invalidStyle.unreadIndicatorColor);
    XCTAssertNotEqual(defaultStyle.cellSeparatorColor, invalidStyle.cellSeparatorColor);

}

- (void)testValidStyle {

    id mockImage = [OCMockObject niceMockForClass:[UIImage class]];
    [[[mockImage stub] andReturn:mockImage] imageNamed:OCMOCK_ANY];

    XCTAssertNoThrow([UADefaultMessageCenterStyle styleWithContentsOfFile:@"Valid-UAMessageCenterDefaultStyle"],
                     @"Parsing a valid UAMessageCenterDefaultStyle file should never result in an exception");

    UADefaultMessageCenterStyle *validStyle = [UADefaultMessageCenterStyle styleWithContentsOfFile:@"Valid-UAMessageCenterDefaultStyle"];

    // Valid-UAMessageCenterDefaultStyle has these values set:
    UIFont *helveticaTestFont = [UIFont fontWithName:@"Helvetica" size:11];
    UIColor *redTestColor = [UAColorUtils colorWithHexString:@"#00FF00"];

    // properties in the valid style plist should match what's set in the style
    XCTAssertEqualObjects(helveticaTestFont, validStyle.titleFont);
    XCTAssertEqualObjects(redTestColor, validStyle.titleColor);
    XCTAssertEqualObjects(redTestColor, validStyle.tintColor);
    XCTAssertEqualObjects(redTestColor, validStyle.navigationBarColor);
    XCTAssertTrue(validStyle.navigationBarOpaque);
    XCTAssertEqualObjects(redTestColor, validStyle.listColor);
    XCTAssertEqualObjects(redTestColor, validStyle.refreshTintColor);
    XCTAssertTrue(validStyle.iconsEnabled);
    XCTAssertEqualObjects(mockImage, validStyle.placeholderIcon);
    XCTAssertEqualObjects(helveticaTestFont, validStyle.cellTitleFont);
    XCTAssertEqualObjects(helveticaTestFont, validStyle.cellDateFont);
    XCTAssertEqualObjects(redTestColor, validStyle.cellColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellHighlightedColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellTitleColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellTitleHighlightedColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellDateColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellDateHighlightedColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellSeparatorColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellTintColor);
    XCTAssertEqualObjects(redTestColor, validStyle.unreadIndicatorColor);

    [mockImage stopMocking];
}

@end
