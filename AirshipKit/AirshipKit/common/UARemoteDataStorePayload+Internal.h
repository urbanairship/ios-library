/* Copyright Urban Airship and Contributors */

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * CoreData class representing the data in the backing store for
 *  UARemoteData objects.
 *
 * This classs should not ordinarily be used directly.
 */
@interface UARemoteDataStorePayload : NSManagedObject

///---------------------------------------------------------------------------------------
/// @name Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The payload type
 */
@property (nullable, nonatomic, copy) NSString *type;

/**
 * The timestamp of the most recent change to this data payload
 */
@property (nullable, nonatomic, copy) NSDate *timestamp;

/**
 * The actual data associated with this payload
 */
@property (nullable, nonatomic, retain) NSDictionary *data;

NS_ASSUME_NONNULL_END

@end
