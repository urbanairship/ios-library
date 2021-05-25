/* Copyright Airship and Contributors */

#import "UARemoteDataStore+Internal.h"
#import "UACoreData.h"
#import "UARemoteDataPayload+Internal.h"
#import "UARemoteDataStorePayload+Internal.h"
#import "UAirship+Internal.h"
#import "UAirshipCoreResources.h"

#define kUARemoteDataDBEntityName @"UARemoteDataStorePayload"

@interface UARemoteDataStore()
@property (strong, nonatomic) UACoreData *coreData;
@end

@implementation UARemoteDataStore

- (instancetype)initWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    self = [super init];
    
    if (self) {

        NSURL *modelURL = [[UAirshipCoreResources bundle] URLForResource:@"UARemoteData" withExtension:@"momd"];
        self.coreData = [UACoreData coreDataWithModelURL:modelURL inMemory:inMemory stores:@[storeName]];
    }
    return self;
}

+ (instancetype)storeWithName:(NSString *)storeName inMemory:(BOOL)inMemory {
    return [[self alloc] initWithName:storeName inMemory:inMemory];
}

+ (instancetype)storeWithName:(NSString *)storeName {
    return [[self alloc] initWithName:storeName inMemory:NO];
}

- (void)fetchRemoteDataFromCacheWithPredicate:(nullable NSPredicate *)predicate
                            completionHandler:(void(^)(NSArray<UARemoteDataStorePayload *>*remoteDataPayloads))completionHandler {
    
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(@[]);
            return;
        }
        
        NSError *error = nil;
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = [NSEntityDescription entityForName:kUARemoteDataDBEntityName
                                     inManagedObjectContext:context];
        
        request.predicate = predicate;
        
        NSArray *resultData = [context executeFetchRequest:request error:&error];
        
        if (error) {
            UA_LERR(@"Error executing fetch request: %@ with error: %@", request, error);
            completionHandler(@[]);
            return;
        }
        
        completionHandler(resultData);
        [UACoreData safeSave:context];
    }];

}

- (void)overwriteCachedRemoteDataWithResponse:(NSArray<UARemoteDataPayload *> *)remoteDataPayloads
                 completionHandler:(void(^)(BOOL))completionHandler {
    [self.coreData safePerformBlock:^(BOOL isSafe, NSManagedObjectContext *context) {
        if (!isSafe) {
            completionHandler(NO);
            return;
        }
        
        // Delete all stored remote data
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kUARemoteDataDBEntityName];
        NSError *error;

        if (self.coreData.inMemory) {
            request.includesPropertyValues = NO;
            NSArray *payloads = [context executeFetchRequest:request error:&error];
            for (NSManagedObject *payload in payloads) {
                [context deleteObject:payload];
            }
        } else {
            NSBatchDeleteRequest *deleteRequest = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
            [context executeRequest:deleteRequest error:&error];
        }

        for (UARemoteDataPayload *remoteDataPayload in remoteDataPayloads) {
            [self addRemoteDataStorePayloadFromRemoteData:remoteDataPayload context:context];
        }
        
        completionHandler([UACoreData safeSave:context]);
    }];
}


- (void)addRemoteDataStorePayloadFromRemoteData:(UARemoteDataPayload *)remoteDataPayload context:(NSManagedObjectContext *)context {
    // create the NSManagedObject
    UARemoteDataStorePayload *remoteDataStorePayload = (UARemoteDataStorePayload *)[NSEntityDescription insertNewObjectForEntityForName:kUARemoteDataDBEntityName
                                                                                                                 inManagedObjectContext:context];
    // set the properties
    remoteDataStorePayload.type = remoteDataPayload.type;
    remoteDataStorePayload.timestamp = remoteDataPayload.timestamp;
    remoteDataStorePayload.data = remoteDataPayload.data;
    remoteDataStorePayload.metadata = remoteDataPayload.metadata;
}

- (void)shutDown {
    [self.coreData shutDown];
}

@end
