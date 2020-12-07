/* Copyright Airship and Contributors */

#import "UAFrequencyConstraint+Internal.h"

@interface UAFrequencyConstraint ()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, assign) NSTimeInterval range;
@property(nonatomic, assign) NSUInteger count;
@end

@implementation UAFrequencyConstraint

+ (instancetype)frequencyConstraintWithIdentifier:(NSString *)identifier
                                            range:(NSTimeInterval)range
                                            count:(NSUInteger)count {

    UAFrequencyConstraint *constraint = [[self alloc] init];
    constraint.identifier = identifier;
    constraint.range = range;
    constraint.count = count;

    return constraint;

}

- (id)copyWithZone:(NSZone *)zone {
    return [UAFrequencyConstraint frequencyConstraintWithIdentifier:self.identifier
                                                              range:self.range
                                                              count:self.count];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (![other isKindOfClass:[self class]]) {
        return NO;
    }

    return [self isEqualToFrequencyConstraint:(UAFrequencyConstraint *)other];
}

- (BOOL)isEqualToFrequencyConstraint:(nullable UAFrequencyConstraint *)other {
    if (self.identifier != other.identifier) {
        return NO;
    }

    if (self.range != other.range) {
        return NO;
    }

    if (self.count != other.count) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + self.range;
    result = 31 * result + self.count;
    result = 31 * result + [self.identifier hash];
    return result;
}

@end
