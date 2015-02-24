
#import "UAInAppNotification.h"
#import "UAUtils.h"
#import "UAColorUtils.h"
#import "UAInAppNotificationButtonActionBinding.h"
#import "UAActionArguments.h"
#import "UAirship+Internal.h"
#import "UAPreferenceDataStore.h"

// 30 days in seconds
#define kUADefaultInAppNotificationExpiryInterval 60 * 60 * 24 * 30

// 15 seconds
#define kUADefaultInAppNotificationDurationInterval 15;


// User defaults key for storing and retrieving pending notifications
#define kUAPendingInAppNotificationDataStoreKey @"com.urbanairship.pending_in_app_notification"

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

    n.primaryColor = [UAColorUtils colorWithHexString:typeCheck(display[@"primary_color"], [NSString class])];
    n.secondaryColor = [UAColorUtils colorWithHexString:typeCheck(display[@"secondary_color"], [NSString class])];

    // actions

    n.buttonGroup = typeCheck(actions[@"button_group"], [NSString class]);
    n.buttonActions = typeCheck(actions[@"button_actions"], [NSDictionary class]);
    n.onClick = typeCheck(actions[@"on_click"], [NSDictionary class]);

    return n;
}

+ (NSDictionary *)pendingNotificationPayload {
    NSDictionary *payload = [[UAirship shared].dataStore objectForKey:kUAPendingInAppNotificationDataStoreKey];
    return payload;
}

+ (instancetype)pendingNotification {
    NSDictionary *payload = [self pendingNotificationPayload];
    if (payload) {
        UAInAppNotification *ian = [self notificationWithPayload:payload];
        [[UAirship shared].dataStore removeObjectForKey:kUAPendingInAppNotificationDataStoreKey];
        return ian;
    }
    return nil;
}

+ (void)storePendingNotificationPayload:(NSDictionary *)payload {
    [[UAirship shared].dataStore setObject:payload forKey:kUAPendingInAppNotificationDataStoreKey];
}

+ (void)deletePendingNotificationPayload {
    [[UAirship shared].dataStore removeObjectForKey:kUAPendingInAppNotificationDataStoreKey];
}

+ (void)deletePendingNotificationPayload:(NSDictionary *)payload {
    if ([[self pendingNotificationPayload] isEqualToDictionary:payload]) {
        [self deletePendingNotificationPayload];
    }
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

    NSString *primaryColor = [UAColorUtils hexStringWithColor:self.primaryColor];
    NSString *secondaryColor = [UAColorUtils hexStringWithColor:self.secondaryColor];

    NSMutableDictionary *display = [NSMutableDictionary dictionary];
    [display setValue:displayType forKey:@"type"];
    [display setValue:position forKey:@"position"];
    [display setValue:alert forKey:@"alert"];
    [display setValue:duration forKey:@"duration"];
    [display setValue:primaryColor forKey:@"primary_color"];
    [display setValue:secondaryColor forKey:@"secondary_color"];
    
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

- (NSArray *)buttonActionBindings {
    NSMutableArray *bindings = [NSMutableArray array];

    // restrict this to iOS 8+ for now
    if (self.buttonGroup && [UIUserNotificationCategory class]) {

        // get the current set of interactive notification categories
        NSSet *categories = [UIApplication sharedApplication].currentUserNotificationSettings.categories;

        for (UIUserNotificationCategory *category in categories) {
            // if there's a match between a category identifier and our button group
            if ([category.identifier isEqualToString:self.buttonGroup]) {
                // create a button action binding for each corresponding action identifier
                for (UIUserNotificationAction *notificationAction in [category actionsForContext:UIUserNotificationActionContextDefault]) {
                    NSDictionary *payload = self.buttonActions[notificationAction.identifier];
                    if (payload) {
                        UAInAppNotificationButtonActionBinding *binding = [[UAInAppNotificationButtonActionBinding alloc] init];
                        binding.localizedTitle = NSLocalizedStringWithDefaultValue(notificationAction.title, @"UAInteractiveNotifications",
                                                                                   [NSBundle mainBundle], notificationAction.title, nil);

                        NSMutableDictionary *actionsDictionary = [NSMutableDictionary dictionary];
                        binding.actions = [NSMutableDictionary dictionary];

                        // choose the situation that matches cthe orresponding notificationAction's activation mode
                        UASituation situation = notificationAction.activationMode == UIUserNotificationActivationModeForeground ?
                            UASituationForegroundInteractiveButton : UASituationBackgroundInteractiveButton;

                        for (NSString *actionName in payload) {
                            actionsDictionary[actionName] = [UAActionArguments argumentsWithValue:payload[actionName] withSituation:situation];
                        }

                        binding.actions = actionsDictionary;

                        [bindings addObject:binding];
                    }
                }
                break;
            }
        }
    }

    // only return bindings if we got a match for each action identifier
    // so we don't end up with the wrong number of buttons
    if (bindings.count == self.buttonActions.count) {
        return bindings;
    } else {
        return [NSArray array];
    }
}

@end
