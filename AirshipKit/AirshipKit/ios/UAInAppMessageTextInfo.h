/* Copyright Urban Airship and Contributors */

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
    UAInAppMessageTextInfoStyleItalic = 1 << 1,
    
    /**
     * Underline style
     */
    UAInAppMessageTextInfoStyleUnderline = 1 << 2
};

/**
 * Represents the possible text alignment options.
 */
typedef NS_ENUM(NSUInteger, UAInAppMessageTextInfoAlignmentType) {
    /**
     * Unspecified alignment (actual alignment specified by container)
     */
    UAInAppMessageTextInfoAlignmentNone = 0,
    
    /**
     * Left Alignment
     */
    UAInAppMessageTextInfoAlignmentLeft = 1,
    
    /**
     * Center Alignment
     */
    UAInAppMessageTextInfoAlignmentCenter = 2,
    
    /**
     * Right Alignment
     */
    UAInAppMessageTextInfoAlignmentRight = 3
};


/**
 * Builder class for UAInAppMessageTextInfo.
 */
@interface UAInAppMessageTextInfoBuilder : NSObject

/**
 * Text content.
 *
 * Required.
 */
@property(nonatomic, copy, nullable) NSString *text;

/**
 * Text color.
 *
 * Optional. Defaults to black.
 */
@property(nonatomic, strong) UIColor *color;

/**
 * Text size.
 *
 * Optional. Defaults to 14sp.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `sizePoints`.
 */
@property(nonatomic, assign) NSUInteger size DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use sizePoints.");

/**
 * Text size.
 *
 * Optional. Defaults to 14sp.
 */
@property(nonatomic, assign) CGFloat sizePoints;

/**
 * Text alignment.
 *
 * Optional. Defaults to UAInAppMessageTextInfoAlignmentNone.
 */
@property(nonatomic, assign) UAInAppMessageTextInfoAlignmentType alignment;

/**
 * Text styles.
 *
 * Optional. Defaults to no style (UAInAppMessageTextInfoStyleNormal).
 */
@property(nonatomic, assign) UAInAppMessageTextInfoStyleType style;

/**
 * Font families - first valid font name in collection is used.
 *
 * Optional
 */
@property(nonatomic, copy, nullable) NSArray<NSString *> *fontFamilies;

/**
 * Checks if the builder is valid and will produce a text info instance.
 * @return YES if the builder is valid (requires text), otherwise NO.
 */
- (BOOL)isValid;

@end

/**
 * Defines the text that appears in an in-app message.
 *
 * @note This object is built using `UAInAppMessageTextInfoBuilder`.
 */
@interface UAInAppMessageTextInfo : NSObject

/**
 * Text content.
 */
@property(nonatomic, readonly, nullable) NSString *text;

/**
 * Text color.
 */
@property(nonatomic, readonly, nullable) UIColor *color;

/**
 * Text size.
 *
 * @deprecated Deprecated - to be removed in SDK version 11.0. Please use `sizePoints`.
 */
@property(nonatomic, readonly) NSUInteger size DEPRECATED_MSG_ATTRIBUTE("Deprecated - to be removed in SDK version 11.0. Please use sizePoints.");

/**
 * Text size.
 */
@property(nonatomic, readonly) CGFloat sizePoints;

/**
 * Text alignment.
 */
@property(nonatomic, readonly) UAInAppMessageTextInfoAlignmentType alignment;

/**
 * Text styles.
 */
@property(nonatomic, readonly) UAInAppMessageTextInfoStyleType style;

/**
 * Font families.
 */
@property(nonatomic, readonly, nullable) NSArray<NSString *> *fontFamilies;

/**
 * Creates an in-app message text info with a builder block.
 *
 * @return The in-app message text info if the builder sucessfully built it, otherwise nil.
 */
+ (nullable instancetype)textInfoWithBuilderBlock:(void(^)(UAInAppMessageTextInfoBuilder *builder))builderBlock;

/**
 * Extends an in-app message text info with a builder block.
 *
 * @return An extended instance of UAInAppMessageTextInfo.
 */
- (nullable UAInAppMessageTextInfo *)extend:(void(^)(UAInAppMessageTextInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

