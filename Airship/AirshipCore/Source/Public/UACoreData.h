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
 * operations. Safe is determined by checking if the context has any persistent stores.
 * @param block A block to perform.
 */
- (void)safePerformBlock:(void (^)(BOOL, NSManagedObjectContext *))block;

/**
 * Performs a synchronous block with the passed in boolean indicating if it's safe to perform
 * operations. Safe is determined by checking if the context has any persistent stores.
 * @param block A block to perform.
 */
- (void)safePerformBlockAndWait:(void (^)(BOOL, NSManagedObjectContext *))block;


+ (BOOL)safeSave:(NSManagedObjectContext *)context;

- (void)shutDown;
- (void)waitForIdle;

@end

NS_ASSUME_NONNULL_END
