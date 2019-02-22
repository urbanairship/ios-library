/* Copyright Urban Airship and Contributors */

#import "UATagGroupsTransactionRecord+Internal.h"

#define kUATagGroupsTransactionRecordMutationKey @"mutation"
#define kUATagGroupsTransactionRecordDateKey @"date"

@interface UATagGroupsTransactionRecord ()

@property(nonatomic, strong) UATagGroupsMutation *mutation;
@property(nonatomic, strong) NSDate *date;

@end

@implementation UATagGroupsTransactionRecord

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutation forKey:kUATagGroupsTransactionRecordMutationKey];
    [coder encodeObject:self.date forKey:kUATagGroupsTransactionRecordDateKey];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.mutation = [coder decodeObjectForKey:kUATagGroupsTransactionRecordMutationKey];
        self.date = [coder decodeObjectForKey:kUATagGroupsTransactionRecordDateKey];
    }

    return self;
}

- (instancetype)initWithMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date {
    self = [super init];

    if (self) {
        self.mutation = mutation;
        self.date = date;
    }

    return self;
}

+ (instancetype)transactionRecordWithMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date {
    return [[self alloc] initWithMutation:mutation date:date];
}

@end
