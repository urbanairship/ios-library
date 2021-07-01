/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @note For internal use only. :nodoc:
 */
@interface UARemoteDataPayload : NSObject <NSCopying>

///---------------------------------------------------------------------------------------
/// @name Properties
///---------------------------------------------------------------------------------------

/**
 * The payload type
 */
@property (nonatomic, copy) NSString *type;

/**
 * The timestamp of the most recent change to this data payload
 */
@property (nonatomic, copy) NSDate *timestamp;

/**
 * The actual data associated with this payload
 */
@property (nonatomic, copy) NSDictionary *data;

/**
 * The metadata associated with this payload
 *
 * Contains important metadata such as locale.
 */
@property (nonatomic, copy) NSDictionary *metadata;

/**
 * Initializes a remote data object.
 *
 * @param type The payload type.
 * @param timestamp The timestamp of the most recent change to this data payload.
 * @param data The actual data associated with this payload.
 * @param metadata The optional metadata associated with this payload such as locale.
 * @return The initialized remote data object.
 */
- (instancetype)initWithType:(NSString *)type
                   timestamp:(NSDate *)timestamp
                        data:(NSDictionary *)data
                    metadata:(nullable NSDictionary *)metadata;

/**
 * Creates an array of remote data objects from an array of JSON dictionaries.
 *
 * @param remoteDataPayloadsAsJSON The array of JSON dictionaries
 * @param metadata The current metadata
 * @return An array of remote data objects.
 */
+ (NSArray<UARemoteDataPayload *> *)remoteDataPayloadsFromJSON:(NSArray *)remoteDataPayloadsAsJSON
                                                      metadata:(NSDictionary *)metadata;


@end

NS_ASSUME_NONNULL_END
