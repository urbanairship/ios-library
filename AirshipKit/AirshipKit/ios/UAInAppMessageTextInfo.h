/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible text styling options.
 */
typedef NS_OPTIONS(NSUInteger, UAInAppMessageTextInfoStyleType) {
    /**
     * Normal style
     */
    UAInAppMessageTextInfoStyleNormal = 0,
    
    /**
     * Bold style
     */
    UAInAppMessageTextInfoStyleBold = 1 << 0,
    
    /**
     * Italic style
     */
    UAInAppMessageTextInfoStyleItalic  = 1 << 1,
    
    /**
     * Underline style
     */
    UAInAppMessageTextInfoStyleUnderline  = 1 << 2
};

/**
 * Builder class for a UAInAppMessageTextInfo object.
 */
@interface UAInAppMessageTextInfoBuilder : NSObject

/**
 * Text content.
 */
@property(nonatomic, copy) NSString *text;

/**
 * Text color. Defaults to black.
 */
@property(nonatomic, strong) UIColor *color;

/**
 * Text size. Defaults to 14sp.
 */
@property(nonatomic, assign) NSUInteger size;

/**
 * Text alignment. Defaults to NSTextAlignmentLeft.
 */
@property(nonatomic, assign) NSTextAlignment alignment;

/**
 * Text styles.
 */
@property(nonatomic, assign) UAInAppMessageTextInfoStyleType style;

/**
 * Font families - first valid font name in collection is used.
 */
@property(nonatomic, copy) NSArray<NSString *> *fontFamilies;

/**
 * Checks if the builder is valid and will produce a text info instance.
 * @return YES if the builder is valid (reuires text), otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Defines the text that appears in an in-app message.
 */
@interface UAInAppMessageTextInfo : NSObject

/**
 * Text content.
 */
@property(nonatomic, copy, readonly, nullable) NSString *text;

/**
 * Text color. Defaults to black.
 */
@property(nonatomic, strong, readonly, nullable) UIColor *color;

/**
 * Text size. Defaults to 14sp.
 */
@property(nonatomic, assign, readonly) NSUInteger size;

/**
 * Text alignment. Defaults to NSTextAlignmentLeft.
 */
@property(nonatomic, assign, readonly) NSTextAlignment alignment;

/**
 * Text styles.
 */
@property(nonatomic, assign, readonly) UAInAppMessageTextInfoStyleType style;

/**
 * Font families.
 */
@property(nonatomic, copy, readonly, nullable) NSArray<NSString *> *fontFamilies;


/**
 * Creates an in-app message text info with a builder block.
 *
 * @return The in-app message text info.
 */
+ (nullable instancetype)textInfoWithBuilderBlock:(void(^)(UAInAppMessageTextInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

