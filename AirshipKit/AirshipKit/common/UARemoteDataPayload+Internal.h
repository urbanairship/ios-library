/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UARemoteDataPayload : NSObject <NSCopying>

///---------------------------------------------------------------------------------------
/// @name Internal Properties
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

///---------------------------------------------------------------------------------------
/// @name Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Initializes a remote data object.
 *
 * @param type The payload type.
 * @param timestamp The timestamp of the most recent change to this data payload.
 * @param data The actual data associated with this payload.
 * @return The initialized remote data object.
 */
- (instancetype)initWithType:(NSString *)type timestamp:(NSDate *)timestamp data:(NSDictionary *)data;

/**
 * Creates an array of remote data objects from an array of JSON dictionaries.
 *
 * @param remoteDataPayloadsAsJSON The array of JSON dictionaries
 * @return An array of remote data objects.
 */
+ (NSArray<UARemoteDataPayload *> *)remoteDataPayloadsFromJSON:(NSArray *)remoteDataPayloadsAsJSON;

@end

NS_ASSUME_NONNULL_END
