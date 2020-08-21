/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsMutation+Internal.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UATagGroupsTransactionRecordType) {
    UATagGroupsTransactionRecordTypeUnknown,
    UATagGroupsTransactionRecordTypeChannel,
    UATagGroupsTransactionRecordTypeNamedUser
};

/**
 * Represents a successful tag groups API transaction, containing a mutation and the
 * date the transaction completed.
 */
@interface UATagGroupsTransactionRecord : NSObject <NSCoding>

/**
 * UATagGroupsTransactionRecord class factory method.
 *
 * @param mutation The tag groups mutation.
 * @param date The date of the mutation.
 * @param type The record type.
 * @param identifier The identifier associated with the transaction.
 */
+ (instancetype)transactionRecordWithMutation:(UATagGroupsMutation *)mutation
                                         date:(NSDate *)date
                                         type:(UATagGroupsTransactionRecordType)type
                                    identifer:(NSString *)identifier;
/**
 * The mutation.
 */
@property(nonatomic, readonly) UATagGroupsMutation *mutation;

/**
 * The date.
 */
@property(nonatomic, readonly) NSDate *date;

/**
 * The Tag group identifier.
 */
@property(nonatomic, readonly) NSString *identifier;

/**
 * The type.
 */
@property(nonatomic, readonly) UATagGroupsTransactionRecordType type;

@end

NS_ASSUME_NONNULL_END
