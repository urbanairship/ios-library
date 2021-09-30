/* Copyright Airship and Contributors */

#import "UAFrequencyLimitManager+Internal.h"
#import "UAFrequencyChecker+Internal.h"
#import "UAFrequencyConstraint+Internal.h"
#import "UAFrequencyConstraintData+Internal.h"
#import "UAOccurrence+Internal.h"
#import "UAOccurrenceData+Internal.h"
#import "UAFrequencyLimitStore+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAFrequencyLimitManager ()
@property(nonatomic, strong) NSMutableDictionary<UAFrequencyConstraint *, NSMutableArray<UAOccurrence *> *> *occurrencesMap;
@property(nonatomic, strong) NSMutableArray<UAOccurrence *> *pendingOccurrences;
@property(nonatomic, strong) UAFrequencyLimitStore *frequencyLimitStore;
@property(nonatomic, strong) UADate *date;
@property(nonatomic, strong) UADispatcher *dispatcher;
@property(nonatomic, strong) id lock;
@end

@implementation UAFrequencyLimitManager

- (instancetype)initWithDataStore:(UAFrequencyLimitStore *)dataStore date:(UADate *)date dispatcher:(UADispatcher *)dispatcher {
    self = [super init];

    if (self) {
        self.frequencyLimitStore = dataStore;
        self.date = date;
        self.pendingOccurrences = [NSMutableArray array];
        self.occurrencesMap = [NSMutableDictionary dictionary];
        self.dispatcher = dispatcher;
        self.lock = [[NSObject alloc] init];
    }

    return self;
}

+ (instancetype)managerWithDataStore:(UAFrequencyLimitStore *)dataStore date:(UADate *)date dispatcher:(UADispatcher *)dispatcher {
    return [[self alloc] initWithDataStore:dataStore date:date dispatcher:dispatcher];
}

+ (instancetype)managerWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithDataStore:[UAFrequencyLimitStore storeWithConfig:config]
                                      date:[[UADate alloc] init]
                                dispatcher:UADispatcher.serial];
}

- (void)getFrequencyChecker:(NSArray<NSString *> *)constraintIDs completionHandler:(void (^)(UAFrequencyChecker *))completionHandler {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        completionHandler([self createFrequencyChecker:[self fetchConstraints:constraintIDs]]);
    }];
}

- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints {
    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)
        NSMutableDictionary<NSString *, UAFrequencyConstraint *> *constraintIDMap = [NSMutableDictionary dictionary];
        NSArray<UAFrequencyConstraint *> *currentConstraints = [self.frequencyLimitStore getConstraints];

        for (UAFrequencyConstraint *constraint in currentConstraints) {
            constraintIDMap[constraint.identifier] = constraint;
        }

        for (UAFrequencyConstraint *constraint in constraints) {
            UAFrequencyConstraint *existing = constraintIDMap[constraint.identifier];
            if (existing) {
                constraintIDMap[constraint.identifier] = nil;
                if (existing.range != constraint.range) {
                    if ([self deleteConstraint:existing]) {
                        [self saveConstraint:constraint];
                    }
                } else {
                    [self saveConstraint:constraint];
                }
            } else {
                [self saveConstraint:constraint];
            }
        }

        [self.frequencyLimitStore deleteConstraints:constraintIDMap.allKeys];
    }];
}

- (void)saveConstraint:(UAFrequencyConstraint *)constraint {
    if (![self.frequencyLimitStore saveConstraint:constraint]) {
        UA_LERR(@"Unable to save constraint: %@", constraint);
    }
}

- (BOOL)deleteConstraint:(UAFrequencyConstraint *)constraint {
    if (![self.frequencyLimitStore deleteConstraint:constraint]) {
        UA_LERR(@"Unable to delete constraint: %@", constraint);
        return NO;
    }

    return YES;
}

- (NSArray<UAFrequencyConstraint *> *)fetchConstraints:(NSArray<NSString *> *)constraintIDs {
    NSArray<UAFrequencyConstraint *> *constraints = [self.frequencyLimitStore getConstraints:constraintIDs];
    for (UAFrequencyConstraint *constraint in constraints) {
        NSMutableArray<UAOccurrence *> *occurrences = [[self.frequencyLimitStore getOccurrences:constraint.identifier] mutableCopy];
        @synchronized(self.lock) {
            for (UAOccurrence *pending in self.pendingOccurrences) {
                if ([pending.parentConstraintID isEqualToString:constraint.identifier]) {
                    [occurrences addObject:pending];
                }
            }

            self.occurrencesMap[constraint] = occurrences;
        }
    }

    return constraints;
}

- (UAFrequencyChecker *)createFrequencyChecker:(NSArray<UAFrequencyConstraint *> *)constraints {
    UA_WEAKIFY(self)
    return [UAFrequencyChecker frequencyCheckerWithIsOverLimit:^{
        UA_STRONGIFY(self)
        return [self isOverLimit:constraints];
    } checkAndIncrement:^{
        UA_STRONGIFY(self)
        return [self checkAndIncrement:constraints];
    }];
}

- (BOOL)isOverLimit:(NSArray<UAFrequencyConstraint *> *)constraints {
    @synchronized(self.lock) {
        for (UAFrequencyConstraint *constraint in constraints) {
            if ([self isConstraintOverLimit:constraint]) {
                return YES;
            }
        }

        return NO;
    }
}

- (BOOL)checkAndIncrement:(NSArray<UAFrequencyConstraint *> *)constraints {
    @synchronized(self.lock) {
        if ([self isOverLimit:constraints]) {
            return NO;
        }

        [self recordOccurrence:[constraints valueForKey:@"identifier"]];

        return YES;
    }

    return NO;
}

- (BOOL)isConstraintOverLimit:(UAFrequencyConstraint *)constraint {
    NSArray<UAOccurrence *> *occurrences = self.occurrencesMap[constraint];
    if (!occurrences || occurrences.count < constraint.count) {
        return NO;
    }

    NSDate *timeStamp = ((UAOccurrence *)occurrences[occurrences.count - constraint.count]).timestamp;
    NSTimeInterval timeSinceOccurrece = [self.date.now timeIntervalSinceDate:timeStamp];
    return timeSinceOccurrece <= constraint.range;
}

- (void)recordOccurrence:(NSArray<NSString *>*)constraintIDs {
    if (!constraintIDs.count) {
        return;
    }

    NSDate *date = self.date.now;
    for (NSString *identifier in constraintIDs) {
        UAOccurrence *occurrence = [UAOccurrence occurrenceWithParentConstraintID:identifier timestamp:date];

        [self.pendingOccurrences addObject:occurrence];

        // Update any currently active constraints
        for (UAFrequencyConstraint *constraint in self.occurrencesMap) {
            if ([identifier isEqualToString:constraint.identifier]) {
                NSMutableArray<UAOccurrence *> *occurrences = self.occurrencesMap[constraint];
                [occurrences addObject:occurrence];
            }
        }
    }

    [self writePendingOccurrences];
}

- (void)writePendingOccurrences {
    [self.dispatcher dispatchAsync:^{
        NSArray<UAOccurrence *> *occurrences;
        @synchronized(self.lock) {
            occurrences = [self.pendingOccurrences copy];
            [self.pendingOccurrences removeAllObjects];
        }

        if (![self.frequencyLimitStore saveOccurrences:occurrences]) {
            UA_LERR(@"Unable to save occurrences: %@", occurrences);
        }
    }];
}

@end
