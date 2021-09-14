/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible error conditions when deserializing data from JSON.
 */
typedef NS_ENUM(NSUInteger, UAScheduleDeferredDataErrorCode) {
    /**
     * Indicates an error with the JSON definition.
     */
    UAScheduleDeferredDataErrorCodeInvalidJSON,
};

/**
 * Represents the possible deferred types.
 */
typedef NS_ENUM(NSUInteger, UAScheduleDataDeferredType) {
    // Unknown type.
    UAScheduleDataDeferredTypeUnknown,

    // In-App message type.
    UAScheduleDataDeferredTypeInAppMessage,
} NS_SWIFT_NAME(ScheduleDataDeferredType);

/**
 * Deferred schedule data.
 */
NS_SWIFT_NAME(ScheduleDeferredData)
@interface UAScheduleDeferredData : NSObject

/**
 * The URL.
 */
@property(nonatomic, readonly) NSURL *URL;

/**
 * Flag for retrying the URL  if the request times out.
 */
@property(nonatomic, readonly, getter=isRetriableOnTimeout) BOOL retriableOnTimeout;

/**
 * The deferred type.
 */
@property(nonatomic, readonly) UAScheduleDataDeferredType type;

/**
 * Factory method.
 * @param URL The URL.
 * @param retriableOnTimeout `YES` to retry on timeout, otherwise `NO`.
 * @return A deferred data instance.
 */
+(instancetype)deferredDataWithURL:(NSURL *)URL
                retriableOnTimeout:(BOOL)retriableOnTimeout;

/**
 * Factory method.
 * @param URL The URL.
 * @param retriableOnTimeout `YES` to retry on timeout, otherwise `NO`.
 * @param type The deferred type.
 * @return A deferred data instance.
 */
+(instancetype)deferredDataWithURL:(NSURL *)URL retriableOnTimeout:(BOOL)retriableOnTimeout type:(UAScheduleDataDeferredType)type;

/**
 * Class factory method for constructing deferred data from JSON.
 *
 * @param json JSON object that defines the data.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A fully configured instance of UAScheduleDeferredData or nil if JSON parsing fails.
 */
+ (nullable instancetype)deferredDataWithJSON:(id)json
                                        error:(NSError * _Nullable *)error;
/**
 * Method to return the data as its JSON representation.
 *
 * @returns JSON representation of the data.
 */
- (NSDictionary *)toJSON;

@end

NS_ASSUME_NONNULL_END
