/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

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
extern NSString *const UAInAppMessageTextInfoAlignmentRight;

/**
 * Center text alignment.
 */
extern NSString *const UAInAppMessageTextInfoAlignmentCenter;

/**
 * Left text alignment.
 */
extern NSString *const UAInAppMessageTextInfoAlignmentLeft;

/**
 * Bold text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleBold;

/**
 * Italic text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleItalic;

/**
 * Underline text style.
 */
extern NSString *const UAInAppMessageTextInfoStyleUnderline;

/**
 * Builder class for a UAInAppMessageTextInfo object.
 */
@interface UAInAppMessageTextInfoBuilder : NSObject

/**
 * Text content.
 */
@property(nonatomic, copy) NSString *text;

/**
 * Text color.
 */
@property(nonatomic, copy) NSString *color;

/**
 * Text size.
 */
@property(nonatomic, assign) NSUInteger size;

/**
 * Text alignment.
 */
@property(nonatomic, copy) NSString *alignment;

/**
 * Text styles.
 */
@property(nonatomic, copy) NSArray<NSString *> *styles;

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
 * Text color.
 */
@property(nonatomic, copy, readonly, nullable) NSString *color;

/**
 * Text size.
 */
@property(nonatomic, assign, readonly) NSUInteger size;

/**
 * Text alignment.
 */
@property(nonatomic, copy, readonly, nullable) NSString *alignment;

/**
 * Text styles.
 */
@property(nonatomic, copy, readonly, nullable) NSArray<NSString *> *styles;

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

