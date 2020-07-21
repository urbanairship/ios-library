/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATagGroupsMutation+Internal.h"

/**
 * Represents a successful tag groups API transaction, containing a mutation and the
 * date the transaction completed.
 */
@interface UATagGroupsTransactionRecord : NSObject <NSCoding>

/**
 * UATagGroupsTransactionRecord class factory method.
 */
+ (instancetype)transactionRecordWithMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date identifer:(NSString *)identifier;

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

@end
