/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAAttributeMutations;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAAttributePayloadKey;
extern NSString *const UAAttributeActionKey;
extern NSString *const UAAttributeValueKey;
extern NSString *const UAAttributeNameKey;
extern NSString *const UAAttributeTimestampKey;
extern NSString *const UAAttributeSetActionKey;
extern NSString *const UAAttributeRemoveActionKey;

/**
 * Defines timestamped and immutable changes to perform on channel attributes that are pending upload.
 * @note For internal use only. :nodoc:
 */
@interface UAAttributePendingMutations : NSObject <NSSecureCoding>

///---------------------------------------------------------------------------------------
/// @name Pending Attribute Mutations Internal Methods
///---------------------------------------------------------------------------------------
///

/**
 Generates a mutations object from an array of mutations and a date for timestamping the mutations. Used for testing.
 @param mutations Attribute mutations object from which to construct the pending mutations.
 @param date A date representing the timestamp of the mutations.
 @return A mutation.
*/
+ (instancetype)pendingMutationsWithMutations:(UAAttributeMutations *)mutations date:(UADate *)date;

/**
 The collection of all current mutations comprising a mutations object.
*/
@property(nonatomic, copy, readonly) NSArray<NSDictionary *> *mutationsPayload;

/**
 Generates an immutable mutations instance from the combined payload of other immutable mutations instances.
 @param mutations Attribute mutations object from which to construct the pending mutations.
 @return A UAAttributePendingMutations instance.
*/
+ (UAAttributePendingMutations *)collapseMutations:(NSArray<UAAttributePendingMutations *> *)mutations;

/**
 The payload for `UAAttributeAPIClient`
 @return An immutable copy of the JSON safe mutations dictionary to be used in a request body or nil if compression resulted in an empty mutation payload.
 */
- (nullable NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
