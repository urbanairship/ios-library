/* Copyright Airship and Contributors */

#import "NSManagedObjectContext+UAAdditions.h"
#import "UAUtils+Internal.h"
#import "UAGlobal.h"

@implementation NSManagedObjectContext (UAAdditions)

NSString *const UAManagedContextStoreDirectory = @"com.urbanairship.no-backup";

+ (NSManagedObjectContext *)managedObjectContextForModelURL:(NSURL *)modelURL
                                           concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType {

    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    [moc setPersistentStoreCoordinator:psc];
    return moc;
}

- (void)addPersistentSqlStore:(NSString *)storeName
            completionHandler:(nonnull void(^)(NSPersistentStore  * _Nullable , NSError * _Nullable))completionHandler {

    [self performBlock:^{


        NSFileManager *fileManager = [NSFileManager defaultManager];

#if TARGET_OS_TV
        NSURL *baseDirectory = [[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
#else
        NSURL *baseDirectory = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
#endif

        NSURL *airshipDirectory = [baseDirectory URLByAppendingPathComponent:UAManagedContextStoreDirectory];

        NSURL *storeURL = [airshipDirectory URLByAppendingPathComponent:storeName];

        if (![fileManager fileExistsAtPath:[airshipDirectory path]]) {
            NSError *error = nil;
            BOOL created = [fileManager createDirectoryAtURL:airshipDirectory
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error];

            if (!created) {
                UA_LTRACE(@"Faaled to create aiship SQL directory. %@", error);
                completionHandler(nil, error);
                return;
            }
        }

        for (NSPersistentStore *store in self.persistentStoreCoordinator.persistentStores) {
            if ([store.URL isEqual:storeURL] && [store.type isEqualToString:NSSQLiteStoreType]) {
                completionHandler(store, nil);
                return;
            }
        }

        NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                                   NSInferMappingModelAutomaticallyOption : @YES };
        NSError *error = nil;

        NSPersistentStore *result = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                                  configuration:nil
                                                                                            URL:storeURL
                                                                                        options:options
                                                                                          error:&error];

        completionHandler(result, error);
    }];
}

- (void)addPersistentInMemoryStore:(NSString *)storeName
                 completionHandler:(nonnull void(^)(NSPersistentStore *, NSError *))completionHandler {

    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES };
    NSError *error = nil;
    NSPersistentStore *result = [self.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                                              configuration:nil
                                                                                        URL:nil
                                                                                    options:options
                                                                                      error:&error];

    completionHandler(result, error);
}

- (void)safePerformBlock:(void (^)(BOOL))block {
    [self performBlock:^{
        if (self.persistentStoreCoordinator.persistentStores.count) {
            block(YES);
        } else {
            block(NO);
        }
    }];
}

- (void)safePerformBlockAndWait:(void (^)(BOOL))block {
    [self performBlockAndWait:^{
        if (self.persistentStoreCoordinator.persistentStores.count) {
            block(YES);
        } else {
            block(NO);
        }
    }];
}

- (BOOL)safeSave {
    NSError *error;
    if (!self.persistentStoreCoordinator.persistentStores.count) {
        UA_LERR(@"Unable to save context. Missing persistent store.");
        return NO;
    }

    if (![self save:&error]) {
        UA_LERR(@"Error saving context %@", error);
        return NO;
    }

    return YES;
}

@end
