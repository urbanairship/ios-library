/* Copyright 2017 Urban Airship and Contributors */

#import "NSManagedObjectContext+UAAdditions.h"
#import "UAUtils.h"
#import "UAGlobal.h"

@implementation NSManagedObjectContext (UAAdditions)

NSString *const UAManagedContextStoreDirectory = @"com.urbanairship.no-backup";

+ (NSManagedObjectContext *)managedObjectContextForModelURL:(NSURL *)modelURL
                                           concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType
                                                  storeName:(NSString *)storeName {

    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    [moc setPersistentStoreCoordinator:psc];

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
            UA_LERR(@"Error creating store directory %@: %@", [cachesStoreDirectoryURL lastPathComponent], error);
            return nil;
        }
    }

    [moc performBlock:^{

        NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                                   NSInferMappingModelAutomaticallyOption : @YES };

        NSError *error = nil;
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];

        if (!store) {
            [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
            store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
        }

        if (!store) {
            UA_LERR(@"Error initializing PSC: %@.", error);
        }
    }];
    
    return moc;
}

@end
