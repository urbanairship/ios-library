/* Copyright Urban Airship and Contributors */

#import "UAMessageCenterStyle.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAColorUtils+Internal.h"
#import "UAMessageCenterStyle.h"

@implementation UAMessageCenterStyle

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default to disabling icons
        self.iconsEnabled = NO;

        // Default to navigation bar translucency to match UIKit
        self.navigationBarOpaque = NO;
    }

    return self;
}

+ (instancetype)style {
    return [[self alloc] init];
}

+ (instancetype)styleWithContentsOfFile:(NSString *)file {
    UAMessageCenterStyle *style = [UAMessageCenterStyle style];
    if (!file) {
        return style;
    }
    NSString *path = [[NSBundle mainBundle] pathForResource:file ofType:@"plist"];

    if (!path) {
        return style;
    }

    NSDictionary *styleDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSDictionary *normalizedStyleDict = [UAMessageCenterStyle normalizeDictionary:styleDict];

    [style setValuesForKeysWithDictionary:normalizedStyleDict];

    UA_LTRACE(@"Message Center style options: %@", [normalizedStyleDict description]);

    return style;
}

// Validates and normalizes style values
+ (NSDictionary *)normalizeDictionary:(NSDictionary *)keyedValues {
    NSMutableDictionary *normalizedValues = [NSMutableDictionary dictionary];

    for (NSString *key in keyedValues) {

        id value = [keyedValues objectForKey:key];

        // Strip whitespace, if necessary
        if ([value isKindOfClass:[NSString class]]){
            value = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }

        // Validate and normalize colors
        if ([key hasSuffix:@"Color"]) {
            [normalizedValues setValue:[UAMessageCenterStyle createColor:value] forKey:key];
            continue;
        }

        // Validate and normalize fonts
        if ([key hasSuffix:@"Font"]) {
            [normalizedValues setValue:[UAMessageCenterStyle createFont:value] forKey:key];
            continue;
        }

        // Validate and normalize icon images
        if ([key hasSuffix:@"Icon"]) {
            [normalizedValues setValue:[UAMessageCenterStyle createIcon:value] forKey:key];
            continue;
        }

        [normalizedValues setValue:value forKey:key];
    }

    return normalizedValues;
}

+(UIColor *)createColor:(NSString *)colorString {

    if (![colorString isKindOfClass:[NSString class]] || ![UAColorUtils colorWithHexString:colorString]) {
        UA_LERR(@"Color must be a valid string representing a valid color hexidecimal");
        return nil;
    }

    return [UAColorUtils colorWithHexString:colorString];;
}

+(UIFont *)createFont:(NSDictionary *)fontDict {

    if (![fontDict isKindOfClass:[NSDictionary class]]) {
        UA_LERR(@"Font name must be a valid string stored under the key \"fontName\".");
        return nil;
    }

    NSString *fontName = fontDict[@"fontName"];
    NSString *fontSize = fontDict[@"fontSize"];

    if (![fontName isKindOfClass:[NSString class]]) {
        UA_LERR(@"Font name must be a valid string stored under the key \"fontName\".");
        return nil;
    }

    if (![fontSize isKindOfClass:[NSString class]]) {
        UA_LERR(@"Font size must be a valid string stored under the key \"fontSize\".");
        return nil;
    }

    if (!([fontSize doubleValue] > 0)) {
        UA_LERR(@"Font name must be a valid string representing a double greater than 0.");
        return nil;
    }

    // Ensure font exists in bundle
    if (![UIFont fontWithName:fontName size:[fontSize doubleValue]]) {
        UA_LERR(@"Font must exist in app bundle.");
        return nil;
    }

    return [UIFont fontWithName:fontDict[@"fontName"]
                           size:[fontDict[@"fontSize"] doubleValue]];;
}

+(UIImage *)createIcon:(NSString *)iconString {

    if (![iconString isKindOfClass:[NSString class]] || ![UIImage imageNamed:iconString]) {
        UA_LERR(@"Icon key must be a valid image name string representing an image file in the bundle.");
        return nil;
    }

    return [UIImage imageNamed:iconString];
}

- (BOOL)isEqualToMessageCenterStyle:(UAMessageCenterStyle *)style {
    if (!style) {
        return NO;
    }
    
    // properties in the valid style plist should match what's set in the style
    BOOL haveEqualTitleFont = (!self.titleFont && !style.titleFont) || [self.titleFont isEqual:style.titleFont];
    BOOL haveEqualtitleColor = (!self.titleColor && !style.titleColor) || [self.titleColor isEqual:style.titleColor];
    BOOL haveEqualtintColor = (!self.tintColor && !style.tintColor) || [self.tintColor isEqual:style.tintColor];
    BOOL haveEqualnavigationBarColor = (!self.navigationBarColor && !style.navigationBarColor) || [self.navigationBarColor isEqual:style.navigationBarColor];
    BOOL haveEqualnavigationBarOpaque = (self.navigationBarOpaque == style.navigationBarOpaque);
    BOOL haveEquallistColor = (!self.listColor && !style.listColor) || [self.listColor isEqual:style.listColor];
    BOOL haveEqualrefreshTintColor = (!self.refreshTintColor && !style.refreshTintColor) || [self.refreshTintColor isEqual:style.refreshTintColor];
    BOOL haveEqualiconsEnabled = (self.iconsEnabled == style.iconsEnabled);
    BOOL haveEqualplaceholderIcon = (!self.placeholderIcon && !style.placeholderIcon) || [self.placeholderIcon isEqual:style.placeholderIcon];
    BOOL haveEqualcellTitleFont = (!self.cellTitleFont && !style.cellTitleFont) || [self.cellTitleFont isEqual:style.cellTitleFont];
    BOOL haveEqualcellDateFont = (!self.cellDateFont && !style.cellDateFont) || [self.cellDateFont isEqual:style.cellDateFont];
    BOOL haveEqualcellColor = (!self.cellColor && !style.cellColor) || [self.cellColor isEqual:style.cellColor];
    BOOL haveEqualcellHighlightedColor = (!self.cellHighlightedColor && !style.cellHighlightedColor) || [self.cellHighlightedColor isEqual:style.cellHighlightedColor];
    BOOL haveEqualcellTitleColor = (!self.cellTitleColor && !style.cellTitleColor) || [self.cellTitleColor isEqual:style.cellTitleColor];
    BOOL haveEqualcellTitleHighlightedColor = (!self.cellTitleHighlightedColor && !style.cellTitleHighlightedColor) || [self.cellTitleHighlightedColor isEqual:style.cellTitleHighlightedColor];
    BOOL haveEqualcellDateColor = (!self.cellDateColor && !style.cellDateColor) || [self.cellDateColor isEqual:style.cellDateColor];
    BOOL haveEqualcellDateHighlightedColor = (!self.cellDateHighlightedColor && !style.cellDateHighlightedColor) || [self.cellDateHighlightedColor isEqual:style.cellDateHighlightedColor];
    BOOL haveEqualcellSeparatorColor = (!self.cellSeparatorColor && !style.cellSeparatorColor) || [self.cellSeparatorColor isEqual:style.cellSeparatorColor];
    BOOL haveEqualcellTintColor = (!self.cellTintColor && !style.cellTintColor) || [self.cellTintColor isEqual:style.cellTintColor];
    BOOL haveEqualunreadIndicatorColor = (!self.unreadIndicatorColor && !style.unreadIndicatorColor) || [self.unreadIndicatorColor isEqual:style.unreadIndicatorColor];
    BOOL haveEqualselectAllButtonTitleColor = (!self.selectAllButtonTitleColor && !style.selectAllButtonTitleColor) || [self.selectAllButtonTitleColor isEqual:style.selectAllButtonTitleColor];
    BOOL haveEqualdeleteButtonTitleColor = (!self.deleteButtonTitleColor && !style.deleteButtonTitleColor) || [self.deleteButtonTitleColor isEqual:style.deleteButtonTitleColor];
    BOOL haveEqualmarkAsReadButtonTitleColor = (!self.markAsReadButtonTitleColor && !style.markAsReadButtonTitleColor) || [self.markAsReadButtonTitleColor isEqual:style.markAsReadButtonTitleColor];

    
    return haveEqualTitleFont &&
        haveEqualtitleColor &&
        haveEqualtintColor &&
        haveEqualnavigationBarColor &&
        haveEqualnavigationBarOpaque &&
        haveEquallistColor &&
        haveEqualrefreshTintColor &&
        haveEqualiconsEnabled &&
        haveEqualplaceholderIcon &&
        haveEqualcellTitleFont &&
        haveEqualcellDateFont &&
        haveEqualcellColor &&
        haveEqualcellHighlightedColor &&
        haveEqualcellTitleColor &&
        haveEqualcellTitleHighlightedColor &&
        haveEqualcellDateColor &&
        haveEqualcellDateHighlightedColor &&
        haveEqualcellSeparatorColor &&
        haveEqualcellTintColor &&
        haveEqualunreadIndicatorColor &&
        haveEqualselectAllButtonTitleColor &&
        haveEqualdeleteButtonTitleColor &&
        haveEqualmarkAsReadButtonTitleColor;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[UAMessageCenterStyle class]]) {
        return NO;
    }
    
    return [self isEqualToMessageCenterStyle:(UAMessageCenterStyle *)object];
}


#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid UAMessageCenterDefaultStyle key: %@", key);
}

@end
