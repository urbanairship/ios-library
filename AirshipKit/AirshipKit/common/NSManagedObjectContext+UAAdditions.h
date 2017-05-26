/* Copyright 2017 Urban Airship and Contributors */

#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (UAAdditions)

/**
 * Creates a managed object context in the UA no backup directory.
 */
+ (instancetype)managedObjectContextForModelURL:(NSURL *)modelURL
                               concurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType
                                      storeName:(NSString *)storeName;
@end
