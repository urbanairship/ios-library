/* Copyright Urban Airship and Contributors */


#import "UANotificationCategory.h"
#import "UANotificationAction.h"

@interface UANotificationCategory ()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSArray<UANotificationAction *> *actions;

/**
 * The intents supported by notifications of this category.
 *
 * Note: This property is only applicable on iOS 10 and above.
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *intentIdentifiers;

/**
 * Flag to indicate a placeholder string was specified.
 *
 * Note: This property is only applicable on iOS 11 and above.
 */
@property(assign, nonatomic) BOOL hiddenPreviewsBodyPlaceholderSpecified;

/**
 * A placeholder string to display when the user has disabled notification previews for the app.
 *
 * Note: This property is only applicable on iOS 11 and above.
 */
@property(copy, nonatomic) NSString *hiddenPreviewsBodyPlaceholder;

/**
 * A format string for a summary description when notifications from this category are grouped together.
 *
 * Note: This property is only applicable on iOS 12 and above.
 */
@property (copy, nonatomic, nullable) NSString *categorySummaryFormat;

/**
 * Options for how to handle notifications of this type.
 */
@property(nonatomic, assign) UANotificationCategoryOptions options;

@end

@implementation UANotificationCategory

- (instancetype)initWithIdentifier:(NSString *)identifier
                           actions:(NSArray<UANotificationAction *> *)actions
                 intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                           options:(UANotificationCategoryOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.actions = actions;
        self.intentIdentifiers = intentIdentifiers;
        self.hiddenPreviewsBodyPlaceholderSpecified = NO;
        self.options = options;
    }

    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           actions:(NSArray<UANotificationAction *> *)actions
                 intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
     hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder
                           options:(UANotificationCategoryOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.actions = actions;
        self.intentIdentifiers = intentIdentifiers;
        self.hiddenPreviewsBodyPlaceholder = hiddenPreviewsBodyPlaceholder;
        self.hiddenPreviewsBodyPlaceholderSpecified = YES;
        self.options = options;
    }

    return self;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                           actions:(NSArray<UANotificationAction *> *)actions
                 intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
     hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder
             categorySummaryFormat:(NSString *)format
                           options:(UANotificationCategoryOptions)options {
    self = [super init];

    if (self) {
        self.identifier = identifier;
        self.actions = actions;
        self.intentIdentifiers = intentIdentifiers;
        self.hiddenPreviewsBodyPlaceholder = hiddenPreviewsBodyPlaceholder;
        self.hiddenPreviewsBodyPlaceholderSpecified = YES;
        self.categorySummaryFormat = format;
        self.options = options;
    }

    return self;
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
                               options:(UANotificationCategoryOptions)options {

    return [[self alloc] initWithIdentifier:identifier
                                    actions:actions
                          intentIdentifiers:intentIdentifiers
                                    options:options];
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
         hiddenPreviewsBodyPlaceholder:(NSString *)hiddenPreviewsBodyPlaceholder
                               options:(UANotificationCategoryOptions)options {

    return [[self alloc] initWithIdentifier:identifier
                                    actions:actions
                          intentIdentifiers:intentIdentifiers
              hiddenPreviewsBodyPlaceholder:hiddenPreviewsBodyPlaceholder
                                    options:options];
}

+ (instancetype)categoryWithIdentifier:(NSString *)identifier
                               actions:(NSArray<UANotificationAction *> *)actions
                     intentIdentifiers:(NSArray<NSString *> *)intentIdentifiers
         hiddenPreviewsBodyPlaceholder:(nullable NSString *)hiddenPreviewsBodyPlaceholder
                 categorySummaryFormat:(nullable NSString *)format
                               options:(UANotificationCategoryOptions)options {
    return [[self alloc] initWithIdentifier:identifier
                                    actions:actions
                          intentIdentifiers:intentIdentifiers
              hiddenPreviewsBodyPlaceholder:hiddenPreviewsBodyPlaceholder
                      categorySummaryFormat:format
                                    options:options];
}

#if !TARGET_OS_TV    // UNNotificationCategory not available on tvOS
- (UNNotificationCategory *)asUNNotificationCategory {
    NSMutableArray *actions = [NSMutableArray array];

    for (UANotificationAction *action in self.actions) {
        UNNotificationAction *converted = [action asUNNotificationAction];
        if (converted) {
            [actions addObject:converted];
        }
    }

    if (@available(iOS 12.0, *)) {
            return [UNNotificationCategory categoryWithIdentifier:self.identifier actions:actions intentIdentifiers:self.intentIdentifiers hiddenPreviewsBodyPlaceholder:self.hiddenPreviewsBodyPlaceholder categorySummaryFormat:self.categorySummaryFormat options:(UNNotificationCategoryOptions)self.options];
    }

    if (@available(iOS 11.0, *)) {
            return [UNNotificationCategory categoryWithIdentifier:self.identifier actions:actions intentIdentifiers:self.intentIdentifiers hiddenPreviewsBodyPlaceholder:self.hiddenPreviewsBodyPlaceholder options:(UNNotificationCategoryOptions)self.options];
    }

    return [UNNotificationCategory categoryWithIdentifier:self.identifier
                                                  actions:actions
                                        intentIdentifiers:self.intentIdentifiers
                                                  options:(UNNotificationCategoryOptions)self.options];

    return nil;
}

- (BOOL)isEqualToUNNotificationCategory:(UNNotificationCategory *)category {
    if (self.actions.count != category.actions.count) {
        return NO;
    }

    for (NSUInteger i = 0; i < self.actions.count; i++) {
        UANotificationAction *uaAction = self.actions[i];
        UNNotificationAction *unAction = category.actions[i];
        if (![uaAction isEqualToUNNotificationAction:unAction]) {
            return NO;
        }
    }

    if (![self.intentIdentifiers isEqualToArray:category.intentIdentifiers]) {
        return NO;
    }

    if (!((NSUInteger)self.options == (NSUInteger)category.options)) {
        return NO;
    }

    if (@available(iOS 11.0, *)) {
        if (![self.hiddenPreviewsBodyPlaceholder isEqualToString:[category valueForKey:@"hiddenPreviewsBodyPlaceholder"]]) {
            return NO;
        }
    }

    if (@available(iOS 12.0, *)) {
        if (![self.categorySummaryFormat isEqualToString:[category valueForKey:@"categorySummaryFormat"]]) {
            return NO;
        }
    }

    return [self.identifier isEqualToString:category.identifier];
}
#endif

@end
