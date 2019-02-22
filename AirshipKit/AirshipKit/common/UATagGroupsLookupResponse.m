/* Copyright Urban Airship and Contributors */

#import "UATagGroupsLookupResponse+Internal.h"

#define kUATagGroupsLookupResponseTagGroupsJSONKey @"tag_groups"
#define kUATagGroupsLookupResponseLastModifiedJSONKey @"last_modified"

#define kUATagGroupsLookupResponseStatusKey @"status"
#define kUATagGroupsLookupResponseTagGroupsKey @"tagGroups"
#define kUATagGroupsLookupResponseLastModifiedTimestampKey @"lastModifiedTimestamp"

@interface UATagGroupsLookupResponse ()

@property(nonatomic, strong) UATagGroups *tagGroups;
@property(nonatomic, copy) NSString *lastModifiedTimestamp;
@property(nonatomic, assign) NSUInteger status;
@end

@implementation UATagGroupsLookupResponse

- (instancetype)initWithTagGroups:(nullable UATagGroups *)tagGroups
                           status:(NSUInteger)status
            lastModifiedTimestamp:(nullable NSString *)lastModifiedTimestamp {

    self = [super init];

    if (self) {
        self.tagGroups = tagGroups;
        self.lastModifiedTimestamp = lastModifiedTimestamp;
        self.status = status;
    }

    return self;
}

+ (instancetype)responseWithTagGroups:(nullable UATagGroups *)tagGroups
                               status:(NSUInteger)status
                lastModifiedTimestamp:(nullable NSString *)lastModifiedTimestamp {

    return [[self alloc] initWithTagGroups:tagGroups status:status lastModifiedTimestamp:lastModifiedTimestamp];
}

+ (instancetype)responseWithJSON:(nullable NSDictionary *)json status:(NSUInteger)status {
    NSDictionary *tags = [json valueForKey:kUATagGroupsLookupResponseTagGroupsJSONKey];
    NSString *lastModifiedTimestamp = [json valueForKey:kUATagGroupsLookupResponseLastModifiedJSONKey];

    UATagGroups *tagGroups;

    if (tags) {
        tagGroups = [UATagGroups tagGroupsWithTags:tags];
    }

    return [self responseWithTagGroups:tagGroups status:status lastModifiedTimestamp:lastModifiedTimestamp];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.tagGroups forKey:kUATagGroupsLookupResponseTagGroupsKey];
    [coder encodeObject:self.lastModifiedTimestamp forKey:kUATagGroupsLookupResponseLastModifiedTimestampKey];
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.status] forKey:kUATagGroupsLookupResponseStatusKey];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];

    if (self) {
        self.tagGroups = [coder decodeObjectForKey:kUATagGroupsLookupResponseTagGroupsKey];
        self.lastModifiedTimestamp = [coder decodeObjectForKey:kUATagGroupsLookupResponseLastModifiedTimestampKey];
        self.status = [[coder decodeObjectForKey:kUATagGroupsLookupResponseStatusKey] unsignedIntegerValue];
    }

    return self;
}

@end
