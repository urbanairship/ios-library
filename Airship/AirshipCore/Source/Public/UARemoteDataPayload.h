/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @note For internal use only. :nodoc:
 */
@interface UARemoteDataPayload : NSObject <NSCopying>

///---------------------------------------------------------------------------------------
/// @name Public Metadata Keys
///---------------------------------------------------------------------------------------

extern NSString *const UARemoteDataMetadataLanguageKey;
extern NSString *const UARemoteDataMetadataCountryKey;
extern NSString *const UARemoteDataMetadataSDKVersionKey;

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


@end

NS_ASSUME_NONNULL_END
