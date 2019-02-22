/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents the possible results of running a retriable.
 */
typedef NS_ENUM(NSUInteger, UARetriableResult) {
    /**
     * Represents a successful result.
     */
    UARetriableResultSuccess = 0,
    /**
     * Represents a retry condition.
     */
    UARetriableResultRetry = 1,
    /**
     * Represents a cancel condition.
     */
    UARetriableResultCancel = 2,
};

/**
 * A block used for signaling and handling retriable results.
 */
typedef void (^UARetriableCompletionHandler)(UARetriableResult);

/**
 * A block comprising the work performed by the retriable.
 */
typedef void (^UARetriableRunBlock)(UARetriableCompletionHandler);

/**
 * An abstract representation of a unit of work that can succeed, automatically retry with backoff, or be canceled.
 */
@interface UARetriable : NSObject

/**
 * The run block.
 */
@property (nonatomic, readonly) UARetriableRunBlock runBlock;

/**
 * The result handler.
 */
@property (nonatomic, readonly) UARetriableCompletionHandler resultHandler;

/**
 * The minimum backoff interval.
 */
@property (nonatomic, readonly) NSTimeInterval minBackoffInterval;

/**
 * The maximum backoff interval.
 */
@property (nonatomic, readonly) NSTimeInterval maxBackoffInterval;

/**
 * UARetriable class factory
 *
 * @param runBlock The run block.
 */
+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock;

/**
 * UARetriable class factory
 *
 * @param runBlock The run block.
 * @param resultHandler A handler which will be called with the result, for any additional
 */
+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock resultHandler:(UARetriableCompletionHandler)resultHandler;

/**
 * UARetriable class factory
 *
 * @param runBlock The run block.
 * @param minBackoffInterval The minimum backoff interval.
 * @param maxBackoffInterval The maximum backoff interval.
 */
+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock
                   minBackoffInterval:(NSTimeInterval)minBackoffInterval
                   maxBackoffInterval:(NSTimeInterval)maxBackoffInterval;

/**
 * UARetriable class factory
 *
 * @param runBlock The run block.
 * @param resultHandler A handler which will be called with the result.
 * @param minBackoffInterval The minimum backoff interval.
 * @param maxBackoffInterval The maximum backoff interval.
 */
+ (instancetype)retriableWithRunBlock:(UARetriableRunBlock)runBlock
                        resultHandler:(UARetriableCompletionHandler)resultHandler
                   minBackoffInterval:(NSTimeInterval)minBackoffInterval
                   maxBackoffInterval:(NSTimeInterval)maxBackoffInterval;

@end

NS_ASSUME_NONNULL_END
