/* Copyright Airship and Contributors */

#import "UAMessageCenterStyle.h"
#import "UAMessageCenterStyle.h"

#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString * const UANavigationBarStyleDefaultKey = @"default";
NSString * const UANavigationBarStyleBlackKey = @"black";

NSString * const UACellSeparatorStyleDefaultKey = @"default";
NSString * const UACellSeparatorStyleNoneKey = @"none";

NSString * const UANavigationBarStyleKey = @"navigationBarStyle";
NSString * const UACellSeparatorStyleKey = @"cellSeparatorStyle";
NSString * const UACellSeparatorInsetKey = @"cellSeparatorInset";

NSString * const UACellSeparatorInsetLeftKey = @"left";
NSString * const UACellSeparatorInsetRightKey = @"right";



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
    NSMutableDictionary *mutableStyle = [normalizedStyleDict mutableCopy];
    [mutableStyle removeObjectForKey:UANavigationBarStyleKey];
    [mutableStyle removeObjectForKey:UACellSeparatorStyleKey];
    [mutableStyle removeObjectForKey:UACellSeparatorInsetKey];

    [style setValuesForKeysWithDictionary:mutableStyle];

    UANavigationBarStyle navBarStyle = [UAMessageCenterStyle parseNavigationBarStyle:normalizedStyleDict];
    style.navigationBarStyle = navBarStyle;
    
    UIEdgeInsets separatorInset = [UAMessageCenterStyle parseEdgeInsets:normalizedStyleDict];
    style.cellSeparatorInset = separatorInset;

    UITableViewCellSeparatorStyle separatorStyle = [UAMessageCenterStyle parseSeparatorStyle:normalizedStyleDict];
    style.cellSeparatorStyle = separatorStyle;
    
    UA_LTRACE(@"Message Center style options: %@", [normalizedStyleDict description]);

    return style;
}

+ (UANavigationBarStyle)parseNavigationBarStyle:(NSDictionary *)styleDict {
    NSString *barStyleString = styleDict[UANavigationBarStyleKey];

    if ([barStyleString isEqualToString:UANavigationBarStyleBlackKey]) {
         return UANavigationBarStyleBlack;
     }

     return UANavigationBarStyleDefault;
}

+ (UIEdgeInsets)parseEdgeInsets:(NSDictionary *)styleDict {
    NSDictionary *insetDict = styleDict[UACellSeparatorInsetKey];

    if (insetDict) {
        id insetLeft = insetDict[UACellSeparatorInsetLeftKey];
        id insetRight = insetDict[UACellSeparatorInsetRightKey];
        
        if ([insetLeft isKindOfClass:[NSNumber class]] && [insetRight isKindOfClass:[NSNumber class]]) {
            UIEdgeInsets separatorInset = UIEdgeInsetsMake(0, [insetLeft floatValue], 0, [insetRight floatValue]);
            return separatorInset;
        } else {
            UA_LERR(@"Both right and left insets must be numbers stored under the keys \"right\" and \"left\" respectively.");
        }
    }
    
    return UIEdgeInsetsZero;
}

+ (UITableViewCellSeparatorStyle)parseSeparatorStyle:(NSDictionary *)styleDict {
    NSString *separatorStyleString = styleDict[UACellSeparatorStyleKey];

    if ([separatorStyleString isEqualToString:UACellSeparatorStyleNoneKey]) {
         return UITableViewCellSeparatorStyleNone;
    }

    return UITableViewCellSeparatorStyleSingleLine;
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

+ (UIColor *)createColor:(NSString *)colorString {
    NSString *errorMessage = @"Color must be a valid string representing either a valid color hexidecimal or a named color corresponding to a color asset in the main bundle.";

    if (![colorString isKindOfClass:[NSString class]]) {
         UA_LERR(@"%@", errorMessage);
         return nil;
     }

    UIColor *hexColor = [UAColorUtils colorWithHexString:colorString];
    UIColor *namedColor;

    // Pull named color from main bundle
    namedColor = [UIColor colorNamed:colorString];

    // Neither a hex nor named color can be determined using the color string
    if (!hexColor && !namedColor) {
        UA_LERR(@"%@", errorMessage);
        return nil;
    }

    // Favor named colors
    return namedColor ?: hexColor;
}

+ (UIFont *)createFont:(NSDictionary *)fontDict {

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
        UA_LERR(@"Font size must be a valid string representing a double greater than 0.");
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

+ (UIImage *)createIcon:(NSString *)iconString {

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
    BOOL haveEqualTitleColor = (!self.titleColor && !style.titleColor) || [self.titleColor isEqual:style.titleColor];
    BOOL haveEqualTintColor = (!self.tintColor && !style.tintColor) || [self.tintColor isEqual:style.tintColor];
    BOOL haveEqualNavigationBarColor = (!self.navigationBarColor && !style.navigationBarColor) || [self.navigationBarColor isEqual:style.navigationBarColor];
    BOOL haveEqualNavigationBarStyle = self.navigationBarStyle == style.navigationBarStyle;
    BOOL haveEqualNavigationBarOpaque = (self.navigationBarOpaque == style.navigationBarOpaque);
    BOOL haveEqualListColor = (!self.listColor && !style.listColor) || [self.listColor isEqual:style.listColor];
    BOOL haveEqualRefreshTintColor = (!self.refreshTintColor && !style.refreshTintColor) || [self.refreshTintColor isEqual:style.refreshTintColor];
    BOOL haveEqualIconsEnabled = (self.iconsEnabled == style.iconsEnabled);
    BOOL haveEqualPlaceholderIcon = (!self.placeholderIcon && !style.placeholderIcon) || [self.placeholderIcon isEqual:style.placeholderIcon];
    BOOL haveEqualCellTitleFont = (!self.cellTitleFont && !style.cellTitleFont) || [self.cellTitleFont isEqual:style.cellTitleFont];
    BOOL haveEqualCellDateFont = (!self.cellDateFont && !style.cellDateFont) || [self.cellDateFont isEqual:style.cellDateFont];
    BOOL haveEqualCellColor = (!self.cellColor && !style.cellColor) || [self.cellColor isEqual:style.cellColor];
    BOOL haveEqualCellHighlightedColor = (!self.cellHighlightedColor && !style.cellHighlightedColor) || [self.cellHighlightedColor isEqual:style.cellHighlightedColor];
    BOOL haveEqualCellTitleColor = (!self.cellTitleColor && !style.cellTitleColor) || [self.cellTitleColor isEqual:style.cellTitleColor];
    BOOL haveEqualCellTitleHighlightedColor = (!self.cellTitleHighlightedColor && !style.cellTitleHighlightedColor) || [self.cellTitleHighlightedColor isEqual:style.cellTitleHighlightedColor];
    BOOL haveEqualCellDateColor = (!self.cellDateColor && !style.cellDateColor) || [self.cellDateColor isEqual:style.cellDateColor];
    BOOL haveEqualCellDateHighlightedColor = (!self.cellDateHighlightedColor && !style.cellDateHighlightedColor) || [self.cellDateHighlightedColor isEqual:style.cellDateHighlightedColor];
    BOOL haveEqualCellSeparatorColor = (!self.cellSeparatorColor && !style.cellSeparatorColor) || [self.cellSeparatorColor isEqual:style.cellSeparatorColor];
    BOOL haveEqualCellSeparatorStyle = (self.cellSeparatorStyle == style.cellSeparatorStyle);
    BOOL haveEqualCellSeparatorInset = (self.cellSeparatorInset.bottom == style.cellSeparatorInset.bottom && self.cellSeparatorInset.top == style.cellSeparatorInset.top && self.cellSeparatorInset.left == style.cellSeparatorInset.left && self.cellSeparatorInset.right == style.cellSeparatorInset.right);
    BOOL haveEqualCellTintColor = (!self.cellTintColor && !style.cellTintColor) || [self.cellTintColor isEqual:style.cellTintColor];
    BOOL haveEqualUnreadIndicatorColor = (!self.unreadIndicatorColor && !style.unreadIndicatorColor) || [self.unreadIndicatorColor isEqual:style.unreadIndicatorColor];
    BOOL haveEqualSelectAllButtonTitleColor = (!self.selectAllButtonTitleColor && !style.selectAllButtonTitleColor) || [self.selectAllButtonTitleColor isEqual:style.selectAllButtonTitleColor];
    BOOL haveEqualDeleteButtonTitleColor = (!self.deleteButtonTitleColor && !style.deleteButtonTitleColor) || [self.deleteButtonTitleColor isEqual:style.deleteButtonTitleColor];
    BOOL haveEqualMarkAsReadButtonTitleColor = (!self.markAsReadButtonTitleColor && !style.markAsReadButtonTitleColor) || [self.markAsReadButtonTitleColor isEqual:style.markAsReadButtonTitleColor];
    BOOL haveEqualEditButtonTitleColor = (!self.editButtonTitleColor && !style.editButtonTitleColor) || [self.editButtonTitleColor isEqual:style.editButtonTitleColor];
    BOOL haveEqualCancelButtonTitleColor = (!self.cancelButtonTitleColor && !style.cancelButtonTitleColor) || [self.cancelButtonTitleColor isEqual:style.cancelButtonTitleColor];

    return haveEqualTitleFont &&
        haveEqualTitleColor &&
        haveEqualTintColor &&
        haveEqualNavigationBarColor &&
        haveEqualNavigationBarStyle &&
        haveEqualNavigationBarOpaque &&
        haveEqualListColor &&
        haveEqualRefreshTintColor &&
        haveEqualIconsEnabled &&
        haveEqualPlaceholderIcon &&
        haveEqualCellTitleFont &&
        haveEqualCellDateFont &&
        haveEqualCellColor &&
        haveEqualCellHighlightedColor &&
        haveEqualCellTitleColor &&
        haveEqualCellTitleHighlightedColor &&
        haveEqualCellDateColor &&
        haveEqualCellDateHighlightedColor &&
        haveEqualCellSeparatorColor &&
        haveEqualCellSeparatorStyle &&
        haveEqualCellSeparatorInset &&
        haveEqualCellTintColor &&
        haveEqualUnreadIndicatorColor &&
        haveEqualSelectAllButtonTitleColor &&
        haveEqualDeleteButtonTitleColor &&
        haveEqualMarkAsReadButtonTitleColor &&
        haveEqualEditButtonTitleColor &&
        haveEqualCancelButtonTitleColor;
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

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.titleColor hash];
    result = 31 * result + [self.tintColor hash];
    result = 31 * result + [self.navigationBarColor hash];
    result = 31 * result + self.navigationBarStyle;
    result = 31 * result + self.navigationBarOpaque;
    result = 31 * result + [self.listColor hash];
    result = 31 * result + [self.refreshTintColor hash];
    result = 31 * result + self.iconsEnabled;
    result = 31 * result + [self.placeholderIcon hash];
    result = 31 * result + [self.cellTitleFont hash];
    result = 31 * result + [self.cellDateFont hash];
    result = 31 * result + [self.cellColor hash];
    result = 31 * result + [self.cellHighlightedColor hash];
    result = 31 * result + [self.cellTitleColor hash];
    result = 31 * result + [self.cellTitleHighlightedColor hash];
    result = 31 * result + [self.cellDateColor hash];
    result = 31 * result + [self.cellDateHighlightedColor hash];
    result = 31 * result + [self.cellSeparatorColor hash];
    result = 31 * result + self.cellSeparatorStyle;
    result = 31 * result + self.cellSeparatorInset.top;
    result = 31 * result + self.cellSeparatorInset.bottom;
    result = 31 * result + self.cellSeparatorInset.left;
    result = 31 * result + self.cellSeparatorInset.right;
    result = 31 * result + [self.cellTintColor hash];
    result = 31 * result + [self.unreadIndicatorColor hash];
    result = 31 * result + [self.selectAllButtonTitleColor hash];
    result = 31 * result + [self.deleteButtonTitleColor hash];
    result = 31 * result + [self.markAsReadButtonTitleColor hash];
    result = 31 * result + [self.editButtonTitleColor hash];
    result = 31 * result + [self.cancelButtonTitleColor hash];

    return result;
}


#pragma mark -
#pragma KVC Overrides
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    // Be leniant and no-op for other undefined keys
    // The `super` implementation throws an exception. We'll just log.
    UA_LDEBUG(@"Ignoring invalid UAMessageCenterDefaultStyle key: %@", key);
}

@end
