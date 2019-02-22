/* Copyright Urban Airship and Contributors */

#import "UARemoteDataStore+Internal.h"
#import "NSManagedObjectContext+UAAdditions+Internal.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UAirship+Internal.h"

#define kUARemoteDataDBEntityName @"UARemoteDataStorePayload"

@interface UARemoteDataStore()
@property (nonatomic, copy) NSString *storeName;
@property (strong, nonatomic) NSManagedObjectContext *managedContext;
@property (nonatomic, assign) BOOL inMemory;
@property (nonatomic, assign) BOOL finished;
@end

@implementation UARemoteDataStore

- (instancetype)initWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    self = [super init];
    
    if (self) {
        self.storeName = storeName;
        self.inMemory = inMemory;
        self.finished = NO;
        
        NSURL *modelURL = [[UAirship resources] URLForResource:@"UARemoteData" withExtension:@"momd"];
        self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                      concurrencyType:NSPrivateQueueConcurrencyType];
        
        [self.managedContext addPersistentSqlStore:self.storeName completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                UA_LERR(@"Failed to create remote data persistent store: %@", error);
                return;
            }
        }];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(protectedDataAvailable)
                                                     name:UIApplicationProtectedDataDidBecomeAvailable
                                                   object:nil];
    }
    return self;
}

+ (instancetype)storeWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    return [[self alloc] initWithName:storeName inMemory:inMemory];
}

+ (instancetype)storeWithName:(NSString *)storeName {
    return [[self alloc] initWithName:storeName inMemory:NO];
}

- (void)protectedDataAvailable {
    if (!self.managedContext.persistentStoreCoordinator.persistentStores.count) {
        [self.managedContext addPersistentSqlStore:self.storeName completionHandler:^(BOOL success, NSError *error) {
            if (!success) {
                UA_LERR(@"Failed to create remote data persistent store: %@", error);
                return;
            }
        }];
    }
}

- (void)safePerformBlock:(void (^)(BOOL))block {
    @synchronized(self) {
        if (!self.finished) {
            [self.managedContext safePerformBlock:block];
        }
    }
}

- (void)fetchRemoteDataFromCacheWithPredicate:(nullable NSPredicate *)predicate
                   completionHandler:(void(^)(NSArray<UARemoteDataStorePayload *>*remoteDataPayloads))completionHandler {
    
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }
        
        NSError *error = nil;
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = [NSEntityDescription entityForName:kUARemoteDataDBEntityName
                                     inManagedObjectContext:self.managedContext];
        
        request.predicate = predicate;
        
        NSArray *resultData = [self.managedContext executeFetchRequest:request error:&error];
        
        if (error) {
            UA_LERR(@"Error executing fetch request: %@ with error: %@", request, error);
            completionHandler(@[]);
            return;
        }
        
        completionHandler(resultData);
        [self.managedContext safeSave];
    }];

}

- (void)overwriteCachedRemoteDataWithResponse:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
                 completionHandler:(void(^)(BOOL))completionHandler {
    [self safePerformBlock:^(BOOL isSafe) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }
        
        // Delete all stored remote data
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUARemoteDataDBEntityName];
        NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        NSError *error;
        [self.managedContext executeRequest:deleteRequest error:&error];

        for (UARemoteDataPayload *remoteDataPayload in remoteDataPayloads) {
            [self addRemoteDataStorePayloadFromRemoteData:remoteDataPayload];
        }
        
        completionHandler([self.managedContext safeSave]);
    }];
}


- (void)addRemoteDataStorePayloadFromRemoteData:(UARemoteDataPayload *)remoteDataPayload {
    // create the NSManagedObject
    UARemoteDataStorePayload *remoteDataStorePayload = (UARemoteDataStorePayload *)[NSEntityDescription insertNewObjectForEntityForName:kUARemoteDataDBEntityName
                                                                                                                 inManagedObjectContext:self.managedContext];
    // set the properties
    remoteDataStorePayload.type = remoteDataPayload.type;
    remoteDataStorePayload.timestamp = remoteDataPayload.timestamp;
    remoteDataStorePayload.data = remoteDataPayload.data;
}

- (void)waitForIdle {
    [self.managedContext performBlockAndWait:^{}];
}

- (void)shutDown {
    @synchronized(self) {
        self.finished = YES;
    }
}

@end
