/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARemoteDataPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface UARemoteDataPayload ()

///---------------------------------------------------------------------------------------
/// @name Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Initializes a remote data object.
 *
 * @param type The payload type.
 * @param timestamp The timestamp of the most recent change to this data payload.
 * @param data The actual data associated with this payload.
 * @param metadata The optional metadata associated with this payload such as locale.
 * @return The initialized remote data object.
 */
- (instancetype)initWithType:(NSString *)type timestamp:(NSDate *)timestamp data:(NSDictionary *)data metadata:(nullable NSDictionary *)metadata;

/**
 * Creates an array of remote data objects from an array of JSON dictionaries.
 *
 * @param remoteDataPayloadsAsJSON The array of JSON dictionaries
 * @param metadata The current metadata
 * @return An array of remote data objects.
 */
+ (NSArray<UARemoteDataPayload *> *)remoteDataPayloadsFromJSON:(NSArray *)remoteDataPayloadsAsJSON metadata:(NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END
