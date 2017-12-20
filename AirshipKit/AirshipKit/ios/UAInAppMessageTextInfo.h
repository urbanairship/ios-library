/* Copyright 2017 Urban Airship and Contributors */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing text info from JSON.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageTextInfoErrorCode) {
    /**
     * Indicates an error with the text info JSON definition.
     */
    UAInAppMessageTextInfoErrorCodeInvalidJSON,
};

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
 * JSON keys.
 */
extern NSString *const UAInAppMessageTextInfoTextKey;
extern NSString *const UAInAppMessageTextInfoColorKey;
extern NSString *const UAInAppMessageTextInfoSizeKey;
extern NSString *const UAInAppMessageTextInfoAlignmentKey;
extern NSString *const UAInAppMessageTextInfoStyleKey;
extern NSString *const UAInAppMessageTextInfoFontFamiliesKey;

/**
 * Right text alignment.
 */
extern NSString *const UAInAppMessageTextInfoAlignmentRightValue;

/**
 * Center text alignment.
 */
extern NSString *const UAInAppMessageTextInfoAlignmentCenterValue;

/**
 * Left text alignment.
 */
extern NSString *const UAInAppMessageTextInfoAlignmentLeftValue;

/**
 * Bold text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleBoldValue;

/**
 * Italic text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleItalicValue;

/**
 * Underline text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleUnderlineValue;

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
 * Factory method to create an in-app message text info from a JSON dictionary.
 *
 * @param json The JSON dictionary.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return An in-app message text info or `nil` if the JSON is invalid.
 */
+ (nullable instancetype)textInfoWithJSON:(id)json error:(NSError * _Nullable *)error;

/**
 * Factory method to create a JSON dictionary from an in-app message text info.
 *
 * @param textInfo An in-app message text info.
 * @return The JSON dictionary.
 */
+ (NSDictionary *)JSONWithTextInfo:(UAInAppMessageTextInfo *)textInfo;

/**
 * Creates an in-app message text info with a builder block.
 *
 * @return The in-app message text info.
 */
+ (nullable instancetype)textInfoWithBuilderBlock:(void(^)(UAInAppMessageTextInfoBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END

