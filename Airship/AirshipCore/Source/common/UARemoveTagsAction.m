/* Copyright Airship and Contributors */

#import "UARemoveTagsAction.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UANamedUser.h"
#import "UATagsActionPredicate+Internal.h"

@implementation UARemoveTagsAction

NSString * const UARemoveTagsActionDefaultRegistryName = @"remove_tags_action";
NSString * const UARemoveTagsActionDefaultRegistryAlias = @"^-t";

// Deprecated - to be removed in SDK version 14.0.
NSString * const kUARemoveTagsActionDefaultRegistryName = UARemoveTagsActionDefaultRegistryName;
NSString * const kUARemoveTagsActionDefaultRegistryAlias = UARemoveTagsActionDefaultRegistryAlias;

- (void)applyChannelTags:(NSArray *)tags {
    [[UAirship channel] removeTags:tags];
}

- (void)applyChannelTags:(NSArray *)tags group:(NSString *)group {
    [[UAirship channel] removeTags:tags group:group];
}

- (void)applyNamedUserTags:(NSArray *)tags group:(NSString *)group {
    [[UAirship namedUser] removeTags:tags group:group];
}

@end
