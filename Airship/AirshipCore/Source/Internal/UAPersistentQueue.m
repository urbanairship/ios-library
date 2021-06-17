/* Copyright Airship and Contributors */

#import "UAPersistentQueue+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

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

- (void)addObject:(id<NSSecureCoding>)object {
    @synchronized(self) {
        NSMutableArray<id<NSSecureCoding>> *objects = [[self objects] mutableCopy];
        [objects addObject:object];
        [self setObjects:objects];
    }
}

- (void)addObjects:(NSArray<id<NSSecureCoding>> *)objects {
    @synchronized(self) {
        NSArray<id<NSSecureCoding>> *newObjects = [self objects];
        newObjects = [newObjects arrayByAddingObjectsFromArray:objects];
        [self setObjects:newObjects];
    }
}

- (nullable id<NSSecureCoding>)peekObject {
    @synchronized(self) {
        NSArray<id<NSSecureCoding>> *objects = [self objects];

        if (!objects.count) {
            return nil;
        }

        return objects[0];
    }
}

- (nullable id<NSSecureCoding>)popObject {
    @synchronized(self) {
        NSMutableArray<id<NSSecureCoding>> *objects = [[self objects] mutableCopy];

        if (!objects.count) {
            return nil;
        }

        id<NSSecureCoding> object = objects[0];
        [objects removeObjectAtIndex:0];

        if (objects.count) {
            [self setObjects:objects];
        } else {
            [self clear];
        }

        return object;
    }
}

- (NSArray<id<NSSecureCoding>> *)objects {
    @synchronized(self) {
        NSData *encodedItems = [self.dataStore objectForKey:self.key];

        if (!encodedItems) {
            return @[];
        }

        return [NSKeyedUnarchiver unarchiveObjectWithData:encodedItems];
    }
}

- (void)setObjects:(NSArray<id<NSSecureCoding>> *)objects {
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

- (void)collapse:(NSArray<id<NSSecureCoding>> * (^)(NSArray<id<NSSecureCoding>> *))block {
    @synchronized (self) {
        NSArray<id<NSSecureCoding>> *result = block([self.objects copy]);
        [self setObjects:result];
    }
}

@end
