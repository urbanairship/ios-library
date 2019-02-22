/* Copyright Urban Airship and Contributors */

#define kUATagGroupsTagsKey @"tags"

#import "UATagGroups+Internal.h"
#import "UAirship.h"
#import "UAPush.h"

@interface UATagGroups ()
@property(nonatomic, copy) NSDictionary *tags;
@end

@implementation UATagGroups

- (instancetype)initWithTags:(NSDictionary *)tags {
    self = [super init];

    if (self) {
        self.tags = [self normalizeTags:tags];
    }

    return self;
}

+ (instancetype)tagGroupsWithTags:(NSDictionary *)tags {
    return [[self alloc] initWithTags:tags];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.tags = [coder decodeObjectForKey:kUATagGroupsTagsKey];
    }

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.tags forKey:kUATagGroupsTagsKey];
}

- (NSDictionary *)normalizeTags:(NSDictionary *)tags {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSString *group in tags) {
        NSSet *set;
        if ([tags[group] isKindOfClass:[NSSet class]]) {
            set = tags[group];
        } else {
            set = [NSSet setWithArray:tags[group]];
        }

        [dictionary setValue:set forKey:group];
    }

    return dictionary;
}

- (BOOL)containsDeviceTags {
    return [self.tags objectForKey:@"device"] != nil;
}

- (BOOL)containsOnlyDeviceTags {
    return self.tags.count == 1 && [self containsDeviceTags];
}

- (BOOL)containsAllTags:(UATagGroups *)tagGroups {
    for (NSString *group in tagGroups.tags) {
        if (![[tagGroups.tags objectForKey:group] isSubsetOfSet:[self.tags objectForKey:group]]) {
            return NO;
        }
    }

    return YES;
}

- (UATagGroups *)intersect:(UATagGroups *)tagGroups {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSString *group in tagGroups.tags) {
        NSMutableSet *set = [[self.tags objectForKey:group] mutableCopy];

        if (set) {
            NSSet *otherSet = [tagGroups.tags objectForKey:group];
            [set intersectSet:otherSet];
            [dictionary setObject:set forKey:group];
        }
    }

    return [UATagGroups tagGroupsWithTags:dictionary];
}

- (UATagGroups *)merge:(UATagGroups *)tagGroups {
    if (!tagGroups.tags.count) {
        return self;
    }

    NSMutableDictionary *newTags = [NSMutableDictionary dictionaryWithDictionary:self.tags];

    for (NSString *group in tagGroups.tags) {
        if ([newTags objectForKey:group]) {
            newTags[group] = [newTags[group] setByAddingObjectsFromSet:tagGroups.tags[group]];
        } else {
            [newTags setObject:tagGroups.tags[group] forKey:group];
        }
    }

    return [UATagGroups tagGroupsWithTags:newTags];
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    for (NSString *group in self.tags) {
        NSArray *array = [self.tags[group] allObjects];
        [dictionary setValue:array forKey:group];
    }

    return dictionary;
}

- (BOOL)isEqualToTagGroups:(UATagGroups *)tagGroups {
    return [self.tags isEqual:tagGroups.tags];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UATagGroups class]]) {
        return NO;
    }

    return [self isEqualToTagGroups:object];
}

- (NSUInteger)hash {
    return [self.tags hash];
}

@end
