
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "UAInAppNotification.h"

@interface UAInAppNotificationTest : XCTestCase
@property(nonatomic, strong) NSDictionary *payload;
@end

@implementation UAInAppNotificationTest

- (void)setUp {
    [super setUp];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};

    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"background_color":@"#ffffffff", @"button_color":@"#ff00ff00"};

    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground", @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};
}

- (void)tearDown {
    [NSUserDefaults resetStandardUserDefaults];
    [super tearDown];
}

/**
 * Helper method for verifying model/payload equivalence 
 */
- (void)verifyPayloadConsistency:(UAInAppNotification *)ian {

    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSGregorianCalendar];
    gregorian.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSDateComponents *expiryComponents =
    [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit) fromDate:ian.expiry];

    XCTAssertEqualObjects(ian.identifier, @"some identifier");

    XCTAssertEqual(expiryComponents.year, 2020);
    XCTAssertEqual(expiryComponents.month, 12);
    XCTAssertEqual(expiryComponents.day, 15);
    XCTAssertEqual(expiryComponents.hour, 11);
    XCTAssertEqual(expiryComponents.minute, 45);
    XCTAssertEqual(expiryComponents.second, 22);

    XCTAssertEqualObjects(ian.extra[@"foo"], self.payload[@"extra"][@"foo"]);
    XCTAssertEqualObjects(ian.extra[@"baz"], self.payload[@"extra"][@"baz"]);

    XCTAssertEqualObjects(ian.alert, self.payload[@"display"][@"alert"]);
    XCTAssertEqual(ian.duration, [self.payload[@"display"][@"duration"] doubleValue]);
    XCTAssertEqual(ian.position, UAInAppNotificationPositionTop);
    XCTAssertEqual(ian.displayType, UAInAppNotificationDisplayTypeBanner);

    XCTAssertEqualObjects(ian.buttonGroup, self.payload[@"actions"][@"button_group"]);
    XCTAssertEqualObjects(ian.onClick, self.payload[@"actions"][@"on_click"]);
    XCTAssertEqualObjects(ian.buttonActions, self.payload[@"actions"][@"button_actions"]);

    XCTAssertEqualObjects(ian.backgroundColor, [UIColor colorWithRed:1 green:1 blue:1 alpha:1]);
    XCTAssertEqualObjects(ian.buttonColor, [UIColor greenColor]);

    XCTAssertEqualObjects(ian.payload, self.payload);
}

- (void)testDefaults {
    UAInAppNotification *ian = [UAInAppNotification notification];
    XCTAssertEqual(ian.displayType, UAInAppNotificationDisplayTypeBanner);
    XCTAssertEqual(ian.position, UAInAppNotificationPositionBottom);

    NSDate *expiry = ian.expiry;
    NSDate *expectedExpiry = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 30];
    XCTAssertEqualWithAccuracy(expiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, 1);
}

/**
 * Test that payloads get turned into model objects properly
 */
- (void)testNotificationWithPayload {
    UAInAppNotification *ian = [UAInAppNotification notificationWithPayload:self.payload];
    [self verifyPayloadConsistency:ian];
}

/**
 * Test that pending notification storage and retrieval works
 */
- (void)testPendingNotification {
    [UAInAppNotification storePendingNotificationPayload:self.payload];

    UAInAppNotification *ian = [UAInAppNotification pendingNotification];
    [self verifyPayloadConsistency:ian];

    // The pending notification should be erased once it's been retrieved.
    XCTAssertNil([UAInAppNotification pendingNotification]);
}

/**
 * Test that notifications can be compared for equality by value
 */
- (void)testIsEqualToNotification {
    UAInAppNotification *ian = [UAInAppNotification notificationWithPayload:self.payload];
    UAInAppNotification *ian2 = [UAInAppNotification notificationWithPayload:self.payload];
    XCTAssertTrue([ian isEqualToNotification:ian2]);

    ian.alert = @"sike!";

    XCTAssertFalse([ian isEqualToNotification:ian2]);
}

- (void)testUnexpectedDisplayAndPosition {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@"yo!", @"type":@"not a type", @"position":@"sideways, starring paul giamatti"};

    weirdPayload[@"display"] = weirdDisplay;
    UAInAppNotification *ian = [UAInAppNotification notificationWithPayload:weirdPayload];

    // default to unknown
    XCTAssertEqual(ian.displayType, UAInAppNotificationDisplayTypeUnknown);

    // default to bottom
    XCTAssertEqual(ian.position, UAInAppNotificationPositionBottom);
}

/**
 * Test that the payload parser drops values that don't conform to the expected type
 */
- (void)testSoftTypeChecking {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@{@"not_a" : @"string"}, @"type":@24, @"duration":@"not a number", @"position":@[@1, @2, @3]};

    weirdPayload[@"display"] = weirdDisplay;

    UAInAppNotification *ian = [UAInAppNotification notificationWithPayload:weirdPayload];

    // alert has no default, so it should be nil in this case
    XCTAssertNil(ian.alert);

    // default to unknown (as opposed to banner, which is the default when constructing a new object)
    XCTAssertEqual(ian.displayType, UAInAppNotificationDisplayTypeUnknown);

    // default to bottom
    XCTAssertEqual(ian.position, UAInAppNotificationPositionBottom);

    // default to 15 seconds
    XCTAssertEqual(ian.duration, 15);
}

@end
