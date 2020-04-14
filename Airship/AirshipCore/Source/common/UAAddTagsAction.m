/* Copyright Airship and Contributors */

#import "UAAddTagsAction.h"
#import "UATagsActionPredicate+Internal.h"
#import "UAChannel.h"
#import "UANamedUser.h"
#import "UAirship.h"

@implementation UAAddTagsAction

NSString * const UAAddTagsActionDefaultRegistryName = @"add_tags_action";
NSString * const UAAddTagsActionDefaultRegistryAlias = @"^+t";

// Deprecated - to be removed in SDK version 14.0.
NSString * const kUAAddTagsActionDefaultRegistryName = UAAddTagsActionDefaultRegistryName;
NSString * const kUAAddTagsActionDefaultRegistryAlias = UAAddTagsActionDefaultRegistryAlias;

- (void)applyChannelTags:(NSArray *)tags {
    [[UAirship channel] addTags:tags];
}

- (void)applyChannelTags:(NSArray *)tags group:(NSString *)group {
    [[UAirship channel] addTags:tags group:group];
}

- (void)applyNamedUserTags:(NSArray *)tags group:(NSString *)group {
    [[UAirship namedUser] addTags:tags group:group];
}

@end
