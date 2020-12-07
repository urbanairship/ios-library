/* Copyright Airship and Contributors */

#import <CoreData/CoreData.h>

#import "UAFrequencyLimitStore+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAAutomationResources.h"
#import "UAOccurrenceData+Internal.h"

static NSString *const FrequencyConstraintEntityName = @"UAFrequencyConstraintData";
static NSString *const OccurrenceEntityName = @"UAOccurrenceData";

@interface UAFrequencyLimitStore ()
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@property (nonatomic, strong) NSPersistentStore *mainStore;
@property (nonatomic, copy) NSString *storeName;
@property (nonatomic, assign) BOOL inMemory;
@property (atomic, assign) BOOL finished;
@end

@implementation UAFrequencyLimitStore

- (instancetype)initWithName:(NSString *)name inMemory:(BOOL)inMemory {
    self = [super init];
    
    if (self){
        self.storeName = name;

        self.inMemory = inMemory;
        self.finished = NO;

        NSBundle *bundle = [UAAutomationResources bundle];
        NSURL *modelURL = [bundle URLForResource:@"UAFrequencyLimits" withExtension:@"momd"];

        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                      concurrencyType:NSPrivateQueueConcurrencyType];
        self.managedContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;

        [self addStores];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(protectedDataAvailable)
                                                     name:UIApplicationProtectedDataDidBecomeAvailable
                                                   object:nil];
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

- (void)addStores {
    UA_WEAKIFY(self)
    void (^completion)(NSPersistentStore *, NSError *) = ^void(NSPersistentStore *store, NSError *error) {
        UA_STRONGIFY(self);

        if (!store) {
            UA_LERR(@"Failed to create automation persistent store: %@", error);
            return;
        }

        if (!self.mainStore) {
            self.mainStore = store;
        }
    };

    if (self.inMemory) {
        [self.managedContext addPersistentInMemoryStore:self.storeName completionHandler:completion];
    } else {
        [self.managedContext addPersistentSqlStore:self.storeName completionHandler:completion];
    }
}

- (void)protectedDataAvailable {
    if (!self.managedContext.persistentStoreCoordinator.persistentStores.count) {
        [self addStores];
    }
}

#pragma mark -
#pragma mark Public Data Access

- (NSArray<UAFrequencyConstraint *> *)getConstraints:(NSArray<NSString *> *)constraintIDs {
    return [self constraintsFromData:[self getConstraintsDataForIDs:constraintIDs]];
}

- (NSArray<UAFrequencyConstraint *> *)getConstraints {
    return [self constraintsFromData:[self getConstraintsData]];
}

- (BOOL)saveConstraint:(UAFrequencyConstraint *)constraint {
    __block BOOL success;

    [self safePerformSync:^ {
        NSArray<UAFrequencyConstraintData *> *result = [self getConstraintsDataForIDs:@[constraint.identifier]];

        if (result.count) {
            [self copyConstraint:constraint data:result.firstObject];
        } else {
            [self addDataForConstraint:constraint];
        }

        success = [self.managedContext safeSave];
    }];

    return success;
}

- (BOOL)deleteConstraints:(NSArray<NSString *> *)constraintIDs {
    __block BOOL success;

    [self safePerformSync:^ {
        NSArray<UAFrequencyConstraintData *> *result = [self getConstraintsDataForIDs:constraintIDs];

        for (UAFrequencyConstraintData * data in result) {
            [self.managedContext deleteObject:data];
            success = [self.managedContext safeSave];
        }
    }];

    return success;
}

- (BOOL)deleteConstraint:(UAFrequencyConstraint *)constraint {
    return [self deleteConstraints:@[constraint.identifier]];
}

- (NSArray<UAOccurrence *> *)getOccurrences:(NSString *)constraintID {
    return [self occurrencesFromData:[self getOccurrencesData:constraintID]];
}

- (BOOL)saveOccurrences:(NSArray<UAOccurrence *> *)occurrences {
    __block BOOL success;

    [self safePerformSync:^ {
        for (UAOccurrence *occurrence in occurrences) {
            UAFrequencyConstraintData *constraintData = [self getConstraintsDataForIDs:@[occurrence.parentConstraintID]].firstObject;
            [self addDataForOccurrence:occurrence constraintData:constraintData];
        }

        success = [self.managedContext safeSave];
    }];

    return success;
}

- (NSArray<UAFrequencyConstraintData *> *)getConstraintsDataForIDs:(NSArray<NSString *> *)constraintIDs {
    if (!constraintIDs.count) {
        return @[];
    }

    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:FrequencyConstraintEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", constraintIDs];

    return [self performFetchRequest:request];
}


- (NSArray<UAFrequencyConstraintData *> *)getConstraintsData {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:FrequencyConstraintEntityName];
    return [self performFetchRequest:request];
}

- (NSArray<UAOccurrenceData *> *)getOccurrencesData:(NSString *)constraintID {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:OccurrenceEntityName];
    request.predicate = [NSPredicate predicateWithFormat:@"constraint.identifier == %@", constraintID];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];

    return [self performFetchRequest:request];
}

#pragma mark -
#pragma mark Helpers

- (void)safePerformSync:(void (^)(void))block {
    if (!self.finished) {
        [self.managedContext safePerformBlockAndWait:^(BOOL safe){
            if (safe && !self.finished) {
                block();
            }
        }];
    }
}

- (id)insertNewEntityForName:(NSString *)name {
    id object = [NSEntityDescription insertNewObjectForEntityForName:name inManagedObjectContext:self.managedContext];

    if (self.mainStore) {
        [self.managedContext assignObject:object toPersistentStore:self.mainStore];
    }

    return object;
}

- (NSArray *)performFetchRequest:(NSFetchRequest *)fetchRequest {
    __block NSArray *result;

    [self safePerformSync:^ {
        NSError *error;
        NSArray *entities = [self.managedContext executeFetchRequest:fetchRequest error:&error];

        if (error) {
            UA_LERR(@"Error fetching entities for name %@: %@", fetchRequest.entityName, error);
        } else {
            result = entities;
        }
    }];

    return result;
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

- (void)addDataForConstraint:(UAFrequencyConstraint *)constraint {
    UAFrequencyConstraintData *data = [self insertNewEntityForName:FrequencyConstraintEntityName];

    data.identifier = constraint.identifier;
    data.count = constraint.count;
    data.range = constraint.range;
}

- (void)addDataForOccurrence:(UAOccurrence *)occurrence constraintData:(UAFrequencyConstraintData *)constraintData {
    UAOccurrenceData *data = [self insertNewEntityForName:OccurrenceEntityName];

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

- (void)waitForIdle {
    [self.managedContext performBlockAndWait:^{}];
}

- (void)shutDown {
    self.finished = YES;
}

@end
