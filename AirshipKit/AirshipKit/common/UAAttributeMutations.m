/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAttributeMutations+Internal.h"
#import "UAAttributePendingMutations+Internal.h"
#import "UAGlobal.h"

NSInteger const UAAttributeMaxStringLength = 1024;

@implementation UAAttributeMutations

+ (instancetype)mutations {
    return [[UAAttributeMutations alloc] init];
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _mutationsPayload = [NSMutableArray array];
    }
    return self;
}

- (void)setString:(NSString *)string forAttribute:(NSString *)attribute {
    NSString *normalizedKey = [self normalizeAttributeString:attribute];
    NSString *normalizedValue = [self normalizeAttributeString:string];

    if (!normalizedValue || !normalizedKey) {
        UA_LDEBUG(@"UAAttributeMutations - Unable to properly form attribute mutation.");
        return;
    }

    NSDictionary *mutationBody = @{
        UAAttributeActionKey : UAAttributeSetActionKey,
        UAAttributeValueKey : normalizedValue,
        UAAttributeNameKey : normalizedKey
    };

    [self.mutationsPayload addObject:mutationBody];
}

- (void)removeAttribute:(NSString *)attribute {
    NSString *normalizedKey = [self normalizeAttributeString:attribute];

    if (!normalizedKey) {
        UA_LDEBUG(@"UAAttributeMutations - Unable to properly form attribute mutation.");
        return;
    }

    NSDictionary *mutationBody = @{
        UAAttributeActionKey : UAAttributeRemoveActionKey,
        UAAttributeNameKey : normalizedKey
    };

    [self.mutationsPayload addObject:mutationBody];
}

- (nullable NSString *)normalizeAttributeString:(NSString *)string {
    if (!string.length || string.length > UAAttributeMaxStringLength) {
        UA_LWARN(@"Attribute strings must be greater than 0 and less than %ld characters in length.", (long)UAAttributeMaxStringLength);
        return nil;
    }

    return string;
}

- (BOOL)isEqualToAttributeMutations:(UAAttributeMutations *)mutations {
    return [self.mutationsPayload isEqual:mutations.mutationsPayload];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAAttributeMutations class]]) {
        return NO;
    }

    return [self isEqualToAttributeMutations:object];
}

- (NSUInteger)hash {
    return [self.mutationsPayload hash];
}

@end
