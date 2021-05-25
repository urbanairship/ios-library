/* Copyright Airship and Contributors */

#import "UACoreData.h"
#import "UAUtils+Internal.h"
#import "UAGlobal.h"

static NSString *const UAManagedContextStoreDirectory = @"com.urbanairship.no-backup";

@interface UACoreData()
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSMutableArray *pendingStores;
@property (assign) BOOL shouldCreateStore;
@property (assign) BOOL inMemory;
@property (assign) BOOL isFinished;
@end

@implementation UACoreData

- (instancetype)initWithContext:(NSManagedObjectContext *)context
                       inMemory:(BOOL)inMemory
                         stores:(NSArray *)stores {
    self = [super init];
    if (self) {
        self.context = context;
        self.pendingStores = [stores mutableCopy];
        self.inMemory = inMemory;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(protectedDataAvailable)
                                                     name:UIApplicationProtectedDataDidBecomeAvailable
                                                   object:nil];
    }
    return self;
}

+ (instancetype)coreDataWithModelURL:(NSURL *)modelURL
                            inMemory:(BOOL)inMemory
                              stores:(NSArray<NSString *> *)stores {
    return [self coreDataWithModelURL:modelURL inMemory:inMemory stores:stores mergePolicy:NSErrorMergePolicy];
}

+ (instancetype)coreDataWithModelURL:(NSURL *)modelURL
                            inMemory:(BOOL)inMemory
                              stores:(NSArray<NSString *> *)stores
                         mergePolicy:(id)mergePolicy {

    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:psc];

    moc.mergePolicy = mergePolicy;

    return [[self alloc] initWithContext:moc inMemory:inMemory stores:stores];
}

- (void)safePerformBlock:(void (^)(BOOL, NSManagedObjectContext *))block {
    [self.context performBlock:^{
        if (self.isFinished) {
            return;
        }

        self.shouldCreateStore = YES;
        [self createPendingStores];

        if (self.context.persistentStoreCoordinator.persistentStores.count) {
            block(YES, self.context);
        } else {
            block(NO, self.context);
        }
    }];
}

- (void)safePerformBlockAndWait:(void (^)(BOOL, NSManagedObjectContext *))block {
    [self.context performBlockAndWait:^{
        if (self.isFinished) {
            return;
        }

        self.shouldCreateStore = YES;
        [self createPendingStores];

        if (self.context.persistentStoreCoordinator.persistentStores.count) {
            block(YES, self.context);
        } else {
            block(NO, self.context);
        }
    }];
}

- (void)shutDown {
    self.isFinished = YES;
}

- (void)waitForIdle {
    [self.context performBlockAndWait:^{}];
}

- (void)protectedDataAvailable {
    [self.context performBlock:^{
        if (self.shouldCreateStore) {
            [self createPendingStores];
        }
    }];
}

- (void)createPendingStores {
    if (self.isFinished) {
        return;
    }

    for (NSString *name in [self.pendingStores copy]) {
        BOOL created = NO;
        if (self.inMemory) {
            created = [self createInMemoryStoreWithName:name];
        } else {
            created = [self createSqlStoreWithName:name];
        }

        if (created) {
            [self.pendingStores removeObject:name];
        }
    }
}

- (BOOL)createInMemoryStoreWithName:(NSString *)storeName {
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES };
    NSError *error = nil;
    NSPersistentStore *result = [self.context.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                                                      configuration:nil
                                                                                                URL:nil
                                                                                            options:options
                                                                                              error:&error];

    if (!result && error) {
        UA_LERR(@"Failed to create store %@: %@", storeName, error);
        return NO;
    } else {
        UA_LDEBUG(@"Created store: %@", storeName);
        [self.delegate persistentStoreCreated:result name:storeName context:self.context];
        return YES;
    }
}

- (BOOL)createSqlStoreWithName:(NSString *)storeName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryDirectoryURL = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *cachesDirectoryURL = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *libraryStoreDirectoryURL = [libraryDirectoryURL URLByAppendingPathComponent:UAManagedContextStoreDirectory];
    NSURL *cachesStoreDirectoryURL = [cachesDirectoryURL URLByAppendingPathComponent:UAManagedContextStoreDirectory];

    NSURL *storeURL;

    // Create the store directory if it doesn't exist
    if ([fileManager fileExistsAtPath:[libraryStoreDirectoryURL path]]) {
        storeURL = [libraryStoreDirectoryURL URLByAppendingPathComponent:storeName];
    } else if ([fileManager fileExistsAtPath:[cachesStoreDirectoryURL path]]) {
        storeURL = [cachesStoreDirectoryURL URLByAppendingPathComponent:storeName];
    } else {
        NSError *error = nil;
        if ([fileManager createDirectoryAtURL:libraryStoreDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            storeURL = [libraryStoreDirectoryURL URLByAppendingPathComponent:storeName];
            [UAUtils addSkipBackupAttributeToItemAtURL:libraryStoreDirectoryURL];
        } else if ([fileManager createDirectoryAtURL:cachesStoreDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            storeURL = [cachesStoreDirectoryURL URLByAppendingPathComponent:storeName];
            [UAUtils addSkipBackupAttributeToItemAtURL:cachesStoreDirectoryURL];
        } else {
            UA_LERR(@"Failed to create store %@: %@", storeName, error);
            return NO;
        }
    }

    // Make sure it does not already exist
    for (NSPersistentStore *store in self.context.persistentStoreCoordinator.persistentStores) {
        if ([store.URL isEqual:storeURL] && [store.type isEqualToString:NSSQLiteStoreType]) {
            return YES;
        }
    }

    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES };
    NSError *error = nil;

    NSPersistentStore *result = [self.context.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                      configuration:nil
                                                                                                URL:storeURL
                                                                                            options:options
                                                                                              error:&error];

    if (!result && error) {
        UA_LERR(@"Failed to create store %@: %@", storeName, error);
        return NO;
    } else {
        UA_LDEBUG(@"Created store: %@", storeName);
        [self.delegate persistentStoreCreated:result name:storeName context:self.context];
        return YES;
    }
}

+ (BOOL)safeSave:(NSManagedObjectContext *)context {
    NSError *error;
    if (!context.persistentStoreCoordinator.persistentStores.count) {
        UA_LERR(@"Unable to save context. Missing persistent store.");
        return NO;
    }

    [context save:&error];

    if (error) {
        UA_LERR(@"Error saving context %@", error);
        return NO;
    }

    return YES;
}

@end
