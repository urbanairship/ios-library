/* Copyright Airship and Contributors */

#import <CoreData/CoreData.h>

#import "UAFrequencyLimitStore+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationResources.h"
#import "UAOccurrenceData+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
static NSString *const FrequencyConstraintEntityName = @"UAFrequencyConstraintData";
static NSString *const OccurrenceEntityName = @"UAOccurrenceData";

@interface UAFrequencyLimitStore ()
@property (nonatomic, strong) UACoreData *coreData;
@end

@implementation UAFrequencyLimitStore

- (instancetype)initWithName:(NSString *)name inMemory:(BOOL)inMemory {
    self = [super init];
    
    if (self){
        NSBundle *bundle = [UAAutomationResources bundle];
        NSURL *modelURL = [bundle URLForResource:@"UAFrequencyLimits" withExtension:@"momd"];
        self.coreData = [[UACoreData alloc] initWithModelURL:modelURL inMemory:inMemory stores:@[name] mergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    }

    return self;
}

+ (instancetype)storeWithName:(NSString *)name inMemory:(BOOL)inMemory {
    return [[self alloc] initWithName:name inMemory:inMemory];
}

+ (instancetype)storeWithConfig:(UARuntimeConfig *)config {
    return [[self alloc] initWithName:[NSString stringWithFormat:@"Frequency-limits-%@.sqlite", config.appKey]
                             inMemory:NO];
}
#pragma mark -
#pragma mark Public Data Access

- (NSArray<UAFrequencyConstraint *> *)getConstraints:(NSArray<NSString *> *)constraintIDs {
    __block NSArray<UAFrequencyConstraint *> *constraints;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            constraints = @[];
            return;
        }

        constraints = [self constraintsFromData:[self getConstraintsDataForIDs:constraintIDs context:context]];
    }];

    return constraints;
}

- (NSArray<UAFrequencyConstraint *> *)getConstraints {
    __block NSArray<UAFrequencyConstraint *> *constraints;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            constraints = @[];
            return;
        }

        constraints = [self constraintsFromData:[self getConstraintsDataWithContext:context]];
    }];

    return constraints;
}

- (BOOL)saveConstraint:(UAFrequencyConstraint *)constraint {
    __block BOOL success;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            success = NO;
            return;
        }

        NSArray<UAFrequencyConstraintData *> *result = [self getConstraintsDataForIDs:@[constraint.identifier] context:context];

        if (result.count) {
            [self copyConstraint:constraint data:result.firstObject];
        } else {
            [self addDataForConstraint:constraint context:context];
        }

        success = [UACoreData safeSave:context];
    }];

    return success;
}

- (BOOL)deleteConstraints:(NSArray<NSString *> *)constraintIDs {
    __block BOOL success;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            success = NO;
            return;
        }

        NSArray<UAFrequencyConstraintData *> *result = [self getConstraintsDataForIDs:constraintIDs context:context];

        for (UAFrequencyConstraintData * data in result) {
            [context deleteObject:data];
            success = [UACoreData safeSave:context];
        }
    }];

    return success;
}

- (BOOL)deleteConstraint:(UAFrequencyConstraint *)constraint {
    return [self deleteConstraints:@[constraint.identifier]];
}

- (NSArray<UAOccurrence *> *)getOccurrences:(NSString *)constraintID {
    __block NSArray<UAOccurrence *> *occurrences;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        occurrences = [self occurrencesFromData:[self getOccurrencesData:constraintID context:context]];
    }];

    return occurrences;
}

- (BOOL)saveOccurrences:(NSArray<UAOccurrence *> *)occurrences {
    __block BOOL success;

    [self.coreData safePerformBlockAndWait:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            success = NO;
            return;
        }

        for (UAOccurrence *occurrence in occurrences) {
            UAFrequencyConstraintData *constraintData = [self getConstraintsDataForIDs:@[occurrence.parentConstraintID] context:context].firstObject;
            [self addDataForOccurrence:occurrence constraintData:constraintData context:context];
        }

        success = [UACoreData safeSave:context];
    }];

    return success;
}


#pragma mark -
#pragma mark Helpers

- (NSArray<UAFrequencyConstraintData *> *)getConstraintsDataForIDs:(NSArray<NSString *> *)constraintIDs context:(NSManagedObjectContext *)context {
    if (!constraintIDs.count) {
        return @[];
    }

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:FrequencyConstraintEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", constraintIDs];

    return [self performFetchRequest:request context:context];
}


- (NSArray<UAFrequencyConstraintData *> *)getConstraintsDataWithContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:FrequencyConstraintEntityName];
    return [self performFetchRequest:request context:context];
}

- (NSArray<UAOccurrenceData *> *)getOccurrencesData:(NSString *)constraintID  context:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:OccurrenceEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"constraint.identifier == %@", constraintID];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];

    return [self performFetchRequest:request context:context];
}

- (NSArray *)performFetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context {
    NSError *error;
    NSArray *entities = [context executeFetchRequest:fetchRequest error:&error];

    if (error) {
        UA_LERR(@"Error fetching entities for name %@: %@", fetchRequest.entityName, error);
        return nil;
    } else {
        return entities;
    }
}

#pragma mark -
#pragma mark Conversion

- (NSArray<UAFrequencyConstraint *> *)constraintsFromData:(NSArray<UAFrequencyConstraintData *> *)constraintsData {
    NSMutableArray *result = [NSMutableArray array];

    for (UAFrequencyConstraintData *data in constraintsData) {
        [result addObject:[UAFrequencyConstraint frequencyConstraintWithIdentifier:data.identifier
                                                                             range:data.range
                                                                             count:data.count]];
    }

    return result;
}

- (NSArray *)occurrencesFromData:(NSArray<UAOccurrenceData *> *)occurrencesData {
    NSMutableArray *result = [NSMutableArray array];

    for (UAOccurrenceData *data in occurrencesData) {
        [result addObject:[UAOccurrence occurrenceWithParentConstraintID:data.constraint.identifier
                                                               timestamp:data.timestamp]];
    }

    return result;
}

- (void)addDataForConstraint:(UAFrequencyConstraint *)constraint context:(NSManagedObjectContext *)context {
    UAFrequencyConstraintData *data = [NSEntityDescription insertNewObjectForEntityForName:FrequencyConstraintEntityName inManagedObjectContext:context];
    data.identifier = constraint.identifier;
    data.count = constraint.count;
    data.range = constraint.range;
}

- (void)addDataForOccurrence:(UAOccurrence *)occurrence constraintData:(UAFrequencyConstraintData *)constraintData context:(NSManagedObjectContext *)context {
    UAOccurrenceData *data = [NSEntityDescription insertNewObjectForEntityForName:OccurrenceEntityName inManagedObjectContext:context];
    data.timestamp = occurrence.timestamp;
    data.constraint = constraintData;
}

- (void)copyConstraint:(UAFrequencyConstraint *)constraint data:(UAFrequencyConstraintData *)data {
    data.identifier = constraint.identifier;
    data.count = constraint.count;
    data.range = constraint.range;
}

#pragma mark -
#pragma mark Testing

- (void)shutDown {
    [self.coreData shutDown];
}

@end

