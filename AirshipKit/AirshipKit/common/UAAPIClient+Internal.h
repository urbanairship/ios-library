/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAConfig.h"
#import "UARequest+Internal.h"
#import "UARequestSession+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAAPIClient : NSObject

/**
 * Status code to indicate the API client is disabled or otherwise unavailable
 */
extern NSUInteger const UAAPIClientStatusUnavailable;

/**
 * The UAConfig instance.
 */
@property (nonatomic, readonly) UAConfig *config;

/**
 * The UARequestSession instance. Should be used to perform requests.
 */
@property (nonatomic, readonly) UARequestSession *session;

/**
 * Flag indicating whether the client is enabled. Clear to disable. Set to enable.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Init method.
 * @param config The UAConfig instance.
 * @param session The UARequestSession instance.
 */
- (instancetype)initWithConfig:(UAConfig *)config session:(UARequestSession *)session;

/**
 * Cancels all in-flight API requests.
 */
- (void)cancelAllRequests;

@end

NS_ASSUME_NONNULL_END
