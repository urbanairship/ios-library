
#import "UAInAppNotification.h"
#import "UAUtils.h"
#import "UAColorUtils.h"

// 30 days in seconds
#define kUADefaultInAppNotificationExpiryInterval 60 * 60 * 24 * 30

// 15 seconds
#define kUADefaultInAppNotificationDurationInterval 15;


// User defaults key for storing and retrieving pending notifications
#define kUAPendingInAppNotificationUserDefaultsKey @"com.urbanairship.pending_in_app_notification"

@implementation UAInAppNotification

+ (instancetype)notification {
    return [[self alloc] init];
}

+ (instancetype)notificationWithPayload:(NSDictionary *)payload {
    UAInAppNotification *n = [[self alloc] init];

    id (^typeCheck)(id, Class) = ^id(id value, Class class) {
        return [value isKindOfClass:class] ? value : nil;
    };

    // top-level keys
    NSString *identifier = typeCheck(payload[@"identifier"], [NSString class]);
    NSString *expiry = typeCheck(payload[@"expiry"], [NSString class]);
    NSDictionary *extra = typeCheck(payload[@"extra"], [NSDictionary class]);
    NSDictionary *display = typeCheck(payload[@"display"], [NSDictionary class]);
    NSDictionary *actions = typeCheck(payload[@"actions"], [NSDictionary class]);

    n.identifier = identifier;

    if (expiry) {
        NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
        n.expiry = [formatter dateFromString:expiry];
    }

    n.extra = extra;

    // display

    NSString *displayType = typeCheck(display[@"type"], [NSString class]);

    if ([displayType isEqualToString:@"banner"]) {
        n.displayType = UAInAppNotificationDisplayTypeBanner;
    } else {
        n.displayType = UAInAppNotificationDisplayTypeUnknown;
    }

    n.alert = typeCheck(display[@"alert"], [NSString class]);

    NSNumber *durationNumber = typeCheck(display[@"duration"], [NSNumber class]);
    if (durationNumber) {
        n.duration = [durationNumber doubleValue];
    }

    NSString *positionString = typeCheck(display[@"position"], [NSString class]);
    if ([positionString isEqualToString:@"top"]) {
        n.position = UAInAppNotificationPositionTop;
    } else if ([positionString isEqualToString:@"bottom"]) {
        n.position = UAInAppNotificationPositionBottom;
    }

    n.fontColor = [UAColorUtils colorWithHexString:typeCheck(display[@"font_color"], [NSString class])];
    n.buttonColor = [UAColorUtils colorWithHexString:typeCheck(display[@"button_color"], [NSString class])];
    n.backgroundColor = [UAColorUtils colorWithHexString:typeCheck(display[@"background_color"], [NSString class])];
    n.buttonFontColor = [UAColorUtils colorWithHexString:typeCheck(display[@"button_font_color"], [NSString class])];

    // actions

    n.buttonGroup = typeCheck(actions[@"button_group"], [NSString class]);
    n.buttonActions = typeCheck(actions[@"button_actions"], [NSDictionary class]);
    n.onClick = typeCheck(actions[@"on_click"], [NSDictionary class]);

    return n;
}

+ (NSDictionary *)pendingNotificationPayload {
    NSDictionary *payload = [[NSUserDefaults standardUserDefaults] objectForKey:kUAPendingInAppNotificationUserDefaultsKey];
    return payload;
}

+ (instancetype)pendingNotification {
    NSDictionary *payload = [self pendingNotificationPayload];
    if (payload) {
        UAInAppNotification *ian = [self notificationWithPayload:payload];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUAPendingInAppNotificationUserDefaultsKey];
        return ian;
    }
    return nil;
}

+ (void)storePendingNotificationPayload:(NSDictionary *)payload {
    [[NSUserDefaults standardUserDefaults] setObject:payload forKey:kUAPendingInAppNotificationUserDefaultsKey];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default values unless otherwise specified
        self.displayType = UAInAppNotificationDisplayTypeBanner;
        self.expiry = [NSDate dateWithTimeIntervalSinceNow:kUADefaultInAppNotificationExpiryInterval];
        self.position = UAInAppNotificationPositionBottom;
        self.duration = kUADefaultInAppNotificationDurationInterval;
    }
    return self;
}

- (BOOL)isEqualToNotification:(UAInAppNotification *)notification {
    return [self.payload isEqualToDictionary:notification.payload];
}

- (NSDictionary *)payload {

    NSDateFormatter *formatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    NSString *expiry = [formatter stringFromDate:self.expiry];

    NSDictionary *extra = self.extra;

    NSString *displayType;
    if (self.displayType == UAInAppNotificationDisplayTypeBanner) {
        displayType = @"banner";
    } else {
        displayType = @"unknown";
    }

    NSString *alert = self.alert;

    NSNumber *duration = [NSNumber numberWithDouble:self.duration];

    NSString *position;
    if (self.position == UAInAppNotificationPositionTop) {
        position = @"top";
    } else if (self.position == UAInAppNotificationPositionBottom) {
        position = @"bottom";
    }

    NSString *backgroundColor = [UAColorUtils hexStringWithColor:self.backgroundColor];
    NSString *fontColor = [UAColorUtils hexStringWithColor:self.fontColor];
    NSString *buttonColor = [UAColorUtils hexStringWithColor:self.buttonColor];
    NSString *buttonFontColor = [UAColorUtils hexStringWithColor:self.buttonFontColor];

    NSMutableDictionary *display = [NSMutableDictionary dictionary];
    [display setValue:displayType forKey:@"type"];
    [display setValue:position forKey:@"position"];
    [display setValue:alert forKey:@"alert"];
    [display setValue:duration forKey:@"duration"];
    [display setValue:backgroundColor forKey:@"background_color"];
    [display setValue:fontColor forKey:@"font_color"];
    [display setValue:buttonColor forKey:@"button_color"];
    [display setValue:buttonFontColor forKey:@"button_font_color"];

    NSMutableDictionary *actions = [NSMutableDictionary dictionary];
    [actions setValue:self.buttonGroup forKey:@"button_group"];
    [actions setValue:self.buttonActions forKey:@"button_actions"];
    [actions setValue:self.onClick forKey:@"on_click"];

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setValue:self.identifier forKey:@"identifier"];
    [payload setValue:expiry forKey:@"expiry"];
    [payload setValue:(extra.count ? extra : nil) forKey:@"extra"];
    [payload setValue:(display.count ? display : nil) forKey:@"display"];
    [payload setValue:(actions.count ?actions : nil) forKey:@"actions"];

    return payload;
}

@end
