/* Copyright Airship and Contributors */

#import "UARemoveTagsAction.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UATagsActionPredicate+Internal.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation UARemoveTagsAction

NSString * const UARemoveTagsActionDefaultRegistryName = @"remove_tags_action";
NSString * const UARemoveTagsActionDefaultRegistryAlias = @"^-t";

- (void)applyChannelTags:(NSArray *)tags {
    [[UAirship channel] removeTags:tags];
}

- (void)applyChannelTags:(NSArray *)tags group:(NSString *)group {
    UATagGroupsEditor *editor = [[UAirship channel] editTagGroups];
    [editor removeTags:tags group:group];
    [editor apply];
}

- (void)applyNamedUserTags:(NSArray *)tags group:(NSString *)group {
    UATagGroupsEditor *editor = [[UAirship contact] editTagGroups];
    [editor removeTags:tags group:group];
    [editor apply];
}

@end
