/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAUtils.h"
#import "UAChannel.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAAttributeMutations+Internal.h"
#import "UADate.h"

NSString *const UAAttributeMutationsCodableKey = @"com.urbanairship.attributes";

/**
 Attribute keys as defined in the specification
 */
NSString *const UAAttributePayloadKey = @"attributes";

NSString *const UAAttributeActionKey = @"action";
NSString *const UAAttributeValueKey = @"value";
NSString *const UAAttributeNameKey = @"key";
NSString *const UAAttributeTimestampKey= @"timestamp";

NSString *const UAAttributeSetActionKey = @"set";
NSString *const UAAttributeRemoveActionKey = @"remove";

@interface UAAttributePendingMutations ()
@property(nonatomic, copy) NSArray<NSDictionary *> *mutationsPayload;
@end

@implementation UAAttributePendingMutations

+ (instancetype)pendingMutationsWithMutations:(UAAttributeMutations *)mutations date:(UADate *)date {
    return [[UAAttributePendingMutations alloc] initWithMutations:mutations date:date];
}

- (instancetype)initWithMutations:(UAAttributeMutations *)mutations date:(UADate *)date {
    self = [super init];

    if (self) {
        self.mutationsPayload = [UAAttributePendingMutations mutationsPayload:mutations
                                                          timestampedWithDate:date];
    }
    return self;
}

- (instancetype)initWithPendingMutationsPayload:(NSArray<NSDictionary *> *)mutationsPayload {
    self = [super init];

    if (self) {
        self.mutationsPayload = mutationsPayload;
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.mutationsPayload = [coder decodeObjectForKey:UAAttributeMutationsCodableKey];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutationsPayload forKey:UAAttributeMutationsCodableKey];
}

+ (NSArray <NSDictionary *>*)mutationsPayload:(UAAttributeMutations *)mutations timestampedWithDate:(UADate *)date {
    NSMutableArray *mutableArr = [NSMutableArray arrayWithArray:mutations.mutationsPayload];

    NSDateFormatter *isoDateFormatter = [UAUtils ISODateFormatterUTCWithDelimiter];
    NSString *timestamp = [isoDateFormatter stringFromDate:date.now];

    for (int i = 0; i < mutableArr.count; i++) {
        NSDictionary *payload = mutableArr[i];
        NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:payload];

        mutableDict[UAAttributeTimestampKey] = timestamp;
        mutableArr[i] = [NSDictionary dictionaryWithDictionary:mutableDict];
    }

    return [NSArray arrayWithArray:mutableArr];
}

- (BOOL)isEqualToPendingMutations:(UAAttributePendingMutations *)mutations {
    return [self.mutationsPayload isEqual:mutations.mutationsPayload];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[self class]]) {
        return NO;
    }

    return [self isEqualToPendingMutations:object];
}

- (NSUInteger)hash {
    return [self.mutationsPayload hash];
}

+ (UAAttributePendingMutations *)collapseMutations:(NSArray<UAAttributePendingMutations *> *)mutations {
    NSMutableArray<NSDictionary *> *allMutationsPayloads = [NSMutableArray array];

    for (UAAttributePendingMutations *mutation in mutations) {
        [allMutationsPayloads addObjectsFromArray:mutation.mutationsPayload];
    }

    NSArray<NSDictionary *> * allMutationsCollapsedPayload = [UAAttributePendingMutations collapseMutationsArray:allMutationsPayloads];

    UAAttributePendingMutations *collapsedMutations = [[UAAttributePendingMutations alloc] initWithPendingMutationsPayload:allMutationsCollapsedPayload];

    return collapsedMutations;
}

+ (NSArray<NSDictionary *> *)collapseMutationsArray:(NSArray<NSDictionary *> *)mutations {
    NSMutableArray *result = [NSMutableArray array];

    for (id mutation in [mutations reverseObjectEnumerator]) {
        NSString *attributeName = mutation[UAAttributeNameKey];
        NSPredicate *keyPredicate = [NSPredicate predicateWithFormat:@"key == %@", attributeName];

        NSArray *filtered = [result filteredArrayUsingPredicate:keyPredicate];

        // Only add latest instance of any key operation
        if (filtered.count == 0) {
            [result insertObject:mutation atIndex:0];
        }
    }

    return [result copy];
}

- (nullable NSDictionary *)payload {
    if (self.mutationsPayload.count == 0) {
        UA_LDEBUG(@"UAAttributePendingMutations - No attribute mutations to add to payload.");
        return nil;
    }

    return @{
        UAAttributePayloadKey : self.mutationsPayload
    };
}

- (NSString *)description {
    return self.payload.description;
}

@end
