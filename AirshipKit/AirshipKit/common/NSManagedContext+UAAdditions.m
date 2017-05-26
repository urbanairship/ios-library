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
    NSURL *directoryURL = [libraryDirectoryURL URLByAppendingPathComponent:UAManagedContextStoreDirectory];

    // Create the store directory if it doesn't exist
    if (![fileManager fileExistsAtPath:[directoryURL path]]) {
        NSError *error = nil;
        if (![fileManager createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            UA_LERR(@"Error creating store directory %@: %@", [directoryURL lastPathComponent], error);
        } else {
            [UAUtils addSkipBackupAttributeToItemAtURL:directoryURL];
        }
    }

    NSURL *storeURL = [directoryURL URLByAppendingPathComponent:storeName];

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
