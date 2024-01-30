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
@property(nonatomic, strong) NSMutableDictionary<NSString *, UAFrequencyConstraint *> *constraintMap;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<UAOccurrence *> *> *occurrencesMap;

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
        self.constraintMap = [NSMutableDictionary dictionary];
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

- (void)getFrequencyChecker:(NSArray<NSString *> *)constraintIDs 
          completionHandler:(void (^)(UAFrequencyChecker *))completionHandler {

    if (!constraintIDs.count) {
        UAFrequencyChecker *checker = [UAFrequencyChecker frequencyCheckerWithIsOverLimit:^{
            return NO;
        } checkAndIncrement:^{
            return YES;
        }];
        completionHandler(checker);
        return;
    }

    UA_WEAKIFY(self)
    [self.dispatcher dispatchAsync:^{
        UA_STRONGIFY(self)

        for (NSString *constraintID in constraintIDs) {
            @synchronized (self.lock) {
                if (self.constraintMap[constraintID]) {
                    // Already loaded
                    continue;
                }
            }

            UAFrequencyConstraint *constraint = [[self.frequencyLimitStore getConstraints:@[constraintID]] firstObject];
            NSMutableArray<UAOccurrence *> *occurrences = [[self.frequencyLimitStore getOccurrences:constraintID] mutableCopy];

            if (!constraint) {
                UA_LERR(@"Failed to get constraint %@", constraint);
                completionHandler(nil);
                return;
            }

            @synchronized (self.lock) {
                self.constraintMap[constraintID] = constraint;
                self.occurrencesMap[constraintID] = occurrences;
            }
        }

        UAFrequencyChecker *checker = [UAFrequencyChecker frequencyCheckerWithIsOverLimit:^{
            return [self isOverLimit:constraintIDs];
        } checkAndIncrement:^{
            return [self checkAndIncrement:constraintIDs];
        }];

        completionHandler(checker);
    }];
}

- (void)updateConstraints:(NSArray<UAFrequencyConstraint *> *)constraints 
        completionHandler:(void (^)(BOOL))completionHandler {

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
                    if (![self.frequencyLimitStore deleteConstraint:existing]) {
                        completionHandler(NO);
                        return;
                    }

                    if (![self.frequencyLimitStore saveConstraint:constraint]) {
                        completionHandler(NO);
                        return;
                    }

                    @synchronized (self.lock) {
                        if (self.constraintMap[constraint.identifier]) {
                            self.constraintMap[constraint.identifier] = constraint;
                            self.occurrencesMap[constraint.identifier] = [NSMutableArray array];
                        }
                    }
                } else {
                    if (![self.frequencyLimitStore saveConstraint:constraint]) {
                        completionHandler(NO);
                        return;
                    }

                    @synchronized (self.lock) {
                        if (self.constraintMap[constraint.identifier]) {
                            self.constraintMap[constraint.identifier] = constraint;
                        }
                    }
                }
            } else {
                if (![self.frequencyLimitStore saveConstraint:constraint]) {
                    completionHandler(NO);
                    return;
                }
            }
        }

        @synchronized (self.lock) {
            for (NSString *constraintID in constraintIDMap.allKeys) {
                [self.constraintMap removeObjectForKey:constraintID];
                [self.occurrencesMap removeObjectForKey:constraintID];
            }
        }

        completionHandler([self.frequencyLimitStore deleteConstraints:constraintIDMap.allKeys]);
    }];
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

- (BOOL)isOverLimit:(NSArray<NSString *> *)constraintIDs {
    @synchronized(self.lock) {
        for (NSString *constraintID in constraintIDs) {
            NSArray<UAOccurrence *> *occurrences = self.occurrencesMap[constraintID];
            UAFrequencyConstraint *constraint = self.constraintMap[constraintID];

            if (!occurrences || !constraint) {
                // Can happen if constraint is removed mid check
                continue;
            }

            if (occurrences.count < constraint.count) {
                continue;
            }

            NSArray *sorted = [occurrences sortedArrayUsingComparator:^NSComparisonResult(UAOccurrence *obj1, UAOccurrence *obj2) {
                return [obj1.timestamp compare:obj2.timestamp];
            }];

            NSDate *timeStamp = ((UAOccurrence *)sorted[occurrences.count - constraint.count]).timestamp;
            NSTimeInterval timeSinceOccurrece = [self.date.now timeIntervalSinceDate:timeStamp];
            if (timeSinceOccurrece <= constraint.range) {
                return YES;
            }
        }

        return NO;
    }
}

- (BOOL)checkAndIncrement:(NSArray<NSString *> *)constraintIDs {
    if (!constraintIDs.count) {
        return YES;
    }

    NSDate *date = self.date.now;

    @synchronized(self.lock) {
        if ([self isOverLimit:constraintIDs]) {
            return NO;
        }

        for (NSString *constraintID in constraintIDs) {
            if (!self.constraintMap[constraintID]) {
                // Can happen if constraint is removed mid check
                continue;
            }

            UAOccurrence *occurrence = [UAOccurrence occurrenceWithParentConstraintID:constraintID timestamp:date];
            [self.pendingOccurrences addObject:occurrence];
            [self.occurrencesMap[constraintID] addObject:occurrence];
        }

        [self writePendingOccurrences];

        return YES;
    }

    return NO;
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
            [self.pendingOccurrences addObjectsFromArray:occurrences];
        }
    }];
}

@end
