/* Copyright Airship and Contributors */

#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@protocol UACoreDataDelegate <NSObject>
- (void)persistentStoreCreated:(NSPersistentStore *)store
                          name:(NSString *)name
                       context:(NSManagedObjectContext *)context;
@end

@interface UACoreData : NSObject

@property (nonatomic, weak) id<UACoreDataDelegate> delegate;
@property (readonly, assign) BOOL inMemory;


+ (instancetype)coreDataWithModelURL:(NSURL *)modelURL
                            inMemory:(BOOL)inMemory
                              stores:(NSArray<NSString *> *) stores;

+ (instancetype)coreDataWithModelURL:(NSURL *)modelURL
                            inMemory:(BOOL)inMemory
                              stores:(NSArray<NSString *> *) stores
                         mergePolicy:(id)mergePolicy;

/**
 * Performs a block with the passed in boolean indicating if it's safe to perform
 * operations, and the context. Safe is determined by checking if the context has any persistent stores.
 *
 * @param block A block to perform.
 */
- (void)safePerformBlock:(void (^)(BOOL, NSManagedObjectContext *))block;

/**
 * Performs a synchronous block with the passed in boolean indicating if it's safe to perform
 * operations, and the context. Safe is determined by checking if the context has any persistent stores.
 *
 * @param block A block to perform.
 */
- (void)safePerformBlockAndWait:(void (^)(BOOL, NSManagedObjectContext *))block;

/**
 * Performs a block with the passed in boolean indicating if it's safe to perform operations, and the context.
 * Safe is determined by checking if the context has any persistent stores. The block will only run if a store exists on disk
 * or if the store is in memory.
 *
 * @param block A block to perform.
 */
- (void)performBlockIfStoresExist:(void (^)(BOOL, NSManagedObjectContext *))block;

/**
 * Saves the current state of the context.
 *
 * @return `YES` if the save was successful, `NO` otherwise.
 */
+ (BOOL)safeSave:(NSManagedObjectContext *)context;

/**
 * Shuts down the datastore and prevents further interaction.
 */
- (void)shutDown;

/**
 * Synchronous method that blocks until all pending operations are complete.
 * Used for testing.
 */
- (void)waitForIdle;

@end

NS_ASSUME_NONNULL_END
