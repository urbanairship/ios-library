/* Copyright Airship and Contributors */

#import "UAInAppMessagingRemoteConfig+Internal.h"
#import "UAInAppMessagingTagGroupsConfig+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#define kUAInAppMessagingRemoteConfigTagGroupsKey @"tag_groups"

@interface UAInAppMessagingRemoteConfig ()
@property (nonatomic, strong) UAInAppMessagingTagGroupsConfig *tagGroupsConfig;
@end

@implementation UAInAppMessagingRemoteConfig

- (instancetype)initWithTagGroupsConfig:(UAInAppMessagingTagGroupsConfig *)tagGroupsConfig {
    self = [super init];

    if (self) {
        self.tagGroupsConfig = tagGroupsConfig;
    }

    return self;
}

+ (instancetype)configWithTagGroupsConfig:(UAInAppMessagingTagGroupsConfig *)tagGroupsConfig {
    return [[self alloc] initWithTagGroupsConfig:tagGroupsConfig];
}

+ (instancetype)defaultConfig {
    return [[self alloc] initWithTagGroupsConfig:[UAInAppMessagingTagGroupsConfig defaultConfig]];
}

+ (nullable instancetype)configWithJSON:(id)JSON {
    if (![JSON isKindOfClass:[NSDictionary class]]) {
        UA_LERR(@"Invalid in-app config: %@", JSON);
        return nil;
    }

    UAInAppMessagingTagGroupsConfig *tagGroupsConfig = [UAInAppMessagingTagGroupsConfig configWithJSON:JSON[kUAInAppMessagingRemoteConfigTagGroupsKey]];
    if (!tagGroupsConfig) {
        return nil;
    }

    return [[self alloc] initWithTagGroupsConfig:tagGroupsConfig];
}

@end
