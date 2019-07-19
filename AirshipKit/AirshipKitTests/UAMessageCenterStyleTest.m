/* Copyright Airship and Contributors */

#import "UABaseTest.h"

#import "UAirship.h"
#import "UAMessageCenter.h"
#import "UAMessageCenterStyle.h"
#import "UAColorUtils+Internal.h"

@interface UAMessageCenterStyleTest : UABaseTest

@property (nonatomic, strong) id mockBundle;

@end

@implementation UAMessageCenterStyleTest

- (void)setUp {
    [super setUp];
    
    self.mockBundle = [self mockForClass:[NSBundle class]];
    //[[[self.mockBundle stub] andReturn:self.mockBundle] mainBundle];
    // Return class bundle instead of main bundle for tests
    [[[self.mockBundle stub] andReturn:[NSBundle bundleForClass:[self class]]] mainBundle];
}

- (void)tearDown {
    [self.mockBundle stopMocking];
    [super tearDown];
}

// Just compare initial values to final value and return
- (void)testInvalidStyle {
    // Whatever is set in the xib (nil in this case)
    UAMessageCenterStyle *defaultStyle = [[UAMessageCenterStyle alloc] init];

    // ensure that unknown/improperly formatted values don't crash the app
    XCTAssertNoThrow([UAMessageCenterStyle styleWithContentsOfFile:@"Invalid-UAMessageCenterDefaultStyle"], @"Parsing an invalid UAMessageCenterDefaultStyle file should never result in an exception" );

    UAMessageCenterStyle *invalidStyle = [UAMessageCenterStyle styleWithContentsOfFile:@"Invalid-UAMessageCenterDefaultStyle"];

    [UAirship messageCenter].style = invalidStyle;

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
    
    XCTAssertNotEqualObjects(defaultStyle, invalidStyle);
}

- (void)testValidStyle {

    id mockImage = [self mockForClass:[UIImage class]];
    [[[mockImage stub] andReturn:mockImage] imageNamed:OCMOCK_ANY];

    XCTAssertNoThrow([UAMessageCenterStyle styleWithContentsOfFile:@"Valid-UAMessageCenterDefaultStyle"],
                     @"Parsing a valid UAMessageCenterDefaultStyle file should never result in an exception");

    UAMessageCenterStyle *validStyle = [UAMessageCenterStyle styleWithContentsOfFile:@"Valid-UAMessageCenterDefaultStyle"];

    // Valid-UAMessageCenterDefaultStyle has these values set:
    UIFont *helveticaTestFont = [UIFont fontWithName:@"Helvetica" size:11];
    UIColor *redTestColor = [UAColorUtils colorWithHexString:@"#FF0000"];
    UIColor *greenTestColor = [UAColorUtils colorWithHexString:@"#00FF00"];
    UIColor *blueTestColor = [UAColorUtils colorWithHexString:@"#0000FF"];

    // properties in the valid style plist should match what's set in the style
    XCTAssertEqualObjects(helveticaTestFont, validStyle.titleFont);
    XCTAssertEqualObjects(redTestColor, validStyle.titleColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.tintColor);
    XCTAssertEqualObjects(blueTestColor, validStyle.navigationBarColor);
    XCTAssertTrue(validStyle.navigationBarOpaque);
    XCTAssertEqualObjects(redTestColor, validStyle.listColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.refreshTintColor);
    XCTAssertTrue(validStyle.iconsEnabled);
    XCTAssertEqualObjects(mockImage, validStyle.placeholderIcon);
    XCTAssertEqualObjects(helveticaTestFont, validStyle.cellTitleFont);
    XCTAssertEqualObjects(helveticaTestFont, validStyle.cellDateFont);
    XCTAssertEqualObjects(blueTestColor, validStyle.cellColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellHighlightedColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.cellTitleColor);
    XCTAssertEqualObjects(blueTestColor, validStyle.cellTitleHighlightedColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellDateColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.cellDateHighlightedColor);
    XCTAssertEqualObjects(blueTestColor, validStyle.cellSeparatorColor);
    XCTAssertEqualObjects(redTestColor, validStyle.cellTintColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.unreadIndicatorColor);
    XCTAssertEqualObjects(redTestColor, validStyle.selectAllButtonTitleColor);
    XCTAssertEqualObjects(greenTestColor, validStyle.deleteButtonTitleColor);
    XCTAssertEqualObjects(blueTestColor, validStyle.markAsReadButtonTitleColor);

    [mockImage stopMocking];
}

// passing in a nil file path should just return the default style
- (void)testNilStyleFile {
    UAMessageCenterStyle *nilStyle = [UAMessageCenterStyle styleWithContentsOfFile:nil];
    UAMessageCenterStyle *defaultStyle = [UAMessageCenterStyle style];
    
    XCTAssertEqualObjects(nilStyle,defaultStyle);
}

@end
