/* Copyright Airship and Contributors */

#import "UATagGroupsTransactionRecord+Internal.h"

#define kUATagGroupsTransactionRecordMutationKey @"mutation"
#define kUATagGroupsTransactionRecordDateKey @"date"
#define kUATagGroupsTransactionRecordIdentifierKey @"identifier"

@interface UATagGroupsTransactionRecord ()

@property(nonatomic, strong) UATagGroupsMutation *mutation;
@property(nonatomic, strong) NSDate *date;
@property(nonatomic, strong) NSString *identifier;

@end

@implementation UATagGroupsTransactionRecord

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutation forKey:kUATagGroupsTransactionRecordMutationKey];
    [coder encodeObject:self.date forKey:kUATagGroupsTransactionRecordDateKey];
    [coder encodeObject:self.identifier forKey:kUATagGroupsTransactionRecordIdentifierKey];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.mutation = [coder decodeObjectForKey:kUATagGroupsTransactionRecordMutationKey];
        self.date = [coder decodeObjectForKey:kUATagGroupsTransactionRecordDateKey];
        self.identifier = [coder decodeObjectForKey:kUATagGroupsTransactionRecordIdentifierKey];
    }

    return self;
}

- (instancetype)initWithMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date identifer:(NSString *)identifier {
    self = [super init];

    if (self) {
        self.mutation = mutation;
        self.date = date;
        self.identifier = identifier;
    }

    return self;
}

+ (instancetype)transactionRecordWithMutation:(UATagGroupsMutation *)mutation date:(NSDate *)date identifer:(NSString *)identifier {
    return [[self alloc] initWithMutation:mutation date:date identifer:identifier];
}

@end
