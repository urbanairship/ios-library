
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * Model object representing a custom style to be applied
 * to the default message center.
 *
 * Note: the customizations exposed in this class are
 * "a la carte". Unless otherwise noted, unspecified
 * properties will be overridden by the default message
 * center at display time.
 */
@interface UADefaultMessageCenterStyle : NSObject

/**
 * The font to use for the message center title.
 */
@property(nonatomic, strong) UIFont *titleFont;

/**
 * The color of the message center title.
 */
@property(nonatomic, strong) UIColor *titleColor;

/**
 * The tint color to be applied to the message center.
 */
@property(nonatomic, strong) UIColor *tintColor;

/**
 * The background color of the navigation bar, if applicable.
 */
@property(nonatomic, strong) UIColor *navigationBarColor;

/**
 * The background color of the message list.
 */
@property(nonatomic, strong) UIColor *listColor;

/**
 * The tint color of the "pull to refresh" control
 */
@property(nonatomic, strong) UIColor *refreshTintColor;

/**
 * Whether icons are enabled. Defaults to `NO`.
 */
@property(nonatomic, assign) BOOL iconsEnabled;

/**
 * An optional placeholder image to use when icons haven't fully loaded.
 */
@property(nonatomic, strong) UIImage *placeholderIcon;

/**
 * The font to use for message cell titles.
 */
@property(nonatomic, strong) UIFont *cellTitleFont;

/**
 * The font to use for message cell dates.
 */
@property(nonatomic, strong) UIFont *cellDateFont;

/**
 * The regular color for message cells 
 */
@property(nonatomic, strong) UIColor *cellColor;

/**
 * The highlighted color for message cells.
 */
@property(nonatomic, strong) UIColor *cellHighlightedColor;

/**
 * The regular color for message cell titles.
 */
@property(nonatomic, strong) UIColor *cellTitleColor;

/**
 * The highlighted color for message cell titles.
 */
@property(nonatomic, strong) UIColor *cellTitleHighlightedColor;

/**
 * The regular color for message cell dates.
 */
@property(nonatomic, strong) UIColor *cellDateColor;

/**
 * The highlighted color for message cell dates.
 */
@property(nonatomic, strong) UIColor *cellDateHighlightedColor;

/**
 * The message cell separator color.
 */
@property(nonatomic, strong) UIColor *cellSeparatorColor;

/**
 * Factory method to create a UADefaultMessageCenterStyle.
 */
+ (instancetype)style;

@end
