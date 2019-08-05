/* Copyright Airship and Contributors */

#import "UAAddTagsAction.h"
#import "UATagsActionPredicate+Internal.h"
#import "UAChannel.h"
#import "UANamedUser.h"
#import "UAirship.h"

@implementation UAAddTagsAction

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
