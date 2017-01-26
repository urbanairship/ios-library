/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

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
        NSError *error = nil;
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];

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
