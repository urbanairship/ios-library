/* Copyright Urban Airship and Contributors */

#import "UAPersistentQueue+Internal.h"

@interface UAPersistentQueue ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, copy) NSString *key;
@end

@implementation UAPersistentQueue

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore key:(NSString *)key {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        self.key = key;
    }

    return self;
}

+ (instancetype)persistentQueueWithDataStore:(UAPreferenceDataStore *)dataStore key:(NSString *)key {
    return [[self alloc] initWithDataStore:dataStore key:key];
}

- (void)addObject:(id<NSCoding>)object {
    @synchronized(self) {
        NSMutableArray<id<NSCoding>> *objects = [[self objects] mutableCopy];
        [objects addObject:object];
        [self setObjects:objects];
    }
}

- (void)addObjects:(NSArray<id<NSCoding>> *)objects {
    @synchronized(self) {
        NSArray<id<NSCoding>> *newObjects = [self objects];
        newObjects = [newObjects arrayByAddingObjectsFromArray:objects];
        [self setObjects:newObjects];
    }
}

- (nullable id<NSCoding>)peekObject {
    @synchronized(self) {
        NSArray<id<NSCoding>> *objects = [self objects];

        if (!objects.count) {
            return nil;
        }

        return objects[0];
    }
}

- (nullable id<NSCoding>)popObject {
    @synchronized(self) {
        NSMutableArray<id<NSCoding>> *objects = [[self objects] mutableCopy];

        if (!objects.count) {
            return nil;
        }

        id<NSCoding> object = objects[0];
        [objects removeObjectAtIndex:0];

        if (objects.count) {
            [self setObjects:objects];
        } else {
            [self clear];
        }

        return object;
    }
}

- (NSArray<id<NSCoding>> *)objects {
    @synchronized(self) {
        NSData *encodedItems = [self.dataStore objectForKey:self.key];

        if (!encodedItems) {
            return @[];
        }

        return [NSKeyedUnarchiver unarchiveObjectWithData:encodedItems];
    }
}

- (void)setObjects:(NSArray<id<NSCoding>> *)objects {
    @synchronized(self) {
        NSData *encodedObjects = [NSKeyedArchiver archivedDataWithRootObject:objects];
        [self.dataStore setObject:encodedObjects forKey:self.key];
    }
}

- (void)clear {
    @synchronized(self) {
        [self.dataStore removeObjectForKey:self.key];
    }
}

@end
