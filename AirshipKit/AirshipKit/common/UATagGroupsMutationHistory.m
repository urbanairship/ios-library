/* Copyright 2018 Urban Airship and Contributors */

#import "UATagGroupsMutationHistory+Internal.h"
#import "UAPreferenceDataStore+InternalTagGroupsMutation.h"

// Prefix for channel tag group keys
NSString *const UAPushTagGroupsKeyPrefix = @"UAPush";

// Prefix for named user tag group keys
NSString *const UANamedUserTagGroupsKeyPrefix = @"UANamedUser";

@interface UATagGroupsMutationHistory ()
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@end

@implementation UATagGroupsMutationHistory

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore {
    self = [super init];

    if (self) {
        self.dataStore = dataStore;
        [self migrateDataStoreKeys];
    }

    return self;
}

+ (instancetype)historyWithDataStore:(UAPreferenceDataStore *)dataStore {
    return [[self alloc] initWithDataStore:dataStore];
}

- (NSString *)prefixForType:(UATagGroupsType)type {
    switch(type) {
        case UATagGroupsTypeChannel:
            return UAPushTagGroupsKeyPrefix;
        case UATagGroupsTypeNamedUser:
            return UANamedUserTagGroupsKeyPrefix;
    }
}

- (NSString *)formattedKey:(NSString *)actionName type:(UATagGroupsType)type {
    return [NSString stringWithFormat:@"%@%@", [self prefixForType:type], actionName];
}

- (NSString *)addTagsKey:(UATagGroupsType)type {
    return [self formattedKey:@"AddTagGroups" type:type];
}

- (NSString *)removeTagsKey:(UATagGroupsType)type {
    return [self formattedKey:@"RemoveTagGroups" type:type];
}

- (NSString *)mutationsKey:(UATagGroupsType)type {
    return [self formattedKey:@"TagGroupsMutations" type:type];
}

- (void)migrateDataStoreKeys {
    for (NSNumber *typeNumber in @[@(UATagGroupsTypeNamedUser), @(UATagGroupsTypeChannel)]) {
        UATagGroupsType type = typeNumber.unsignedIntegerValue;
        [self.dataStore migrateTagGroupSettingsForAddTagsKey:[self addTagsKey:type]
                                               removeTagsKey:[self removeTagsKey:type]
                                                      newKey:[self mutationsKey:type]];
    }
}

- (UATagGroupsMutation *)peekMutation:(UATagGroupsType)type {
    return [self.dataStore peekTagGroupsMutationForKey:[self mutationsKey:type]];
}

- (UATagGroupsMutation *)popMutation:(UATagGroupsType)type {
    return [self.dataStore popTagGroupsMutationForKey:[self mutationsKey:type]];
}

- (void)addMutation:(UATagGroupsMutation *)mutation type:(UATagGroupsType)type {
    [self.dataStore addTagGroupsMutation:mutation forKey:[self mutationsKey:type]];
}

- (void)collapseHistory:(UATagGroupsType)type {
    [self.dataStore collapseTagGroupsMutationForKey:[self mutationsKey:type]];
}

- (void)clearHistory:(UATagGroupsType)type {
    [self.dataStore removeObjectForKey:[self mutationsKey:type]];
}

@end
