/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * HTTP response.
 * @note For internal use only. :nodoc:
 */
@interface UAHTTPResponse : NSObject

/**
 * The HTTP status.
 */
@property(nonatomic, assign, readonly) NSUInteger status;

/**
 * Init method.
 * @param status The status.
 */
- (instancetype)initWithStatus:(NSUInteger)status;

/**
 * Checks if the status is success (2xx).
 * @return `YES` if success, otherwise `NO`.
 */
- (bool)isSuccess;

/**
 * Checks if the status is client error (4xx).
 * @return `YES` if client error, otherwise `NO`.
 */
- (bool)isClientError;

/**
 * Checks if the status is server error (5xx).
 * @return `YES` if server error, otherwise `NO`.
 */
- (bool)isServerError;

@end

NS_ASSUME_NONNULL_END
