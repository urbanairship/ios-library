/* Copyright Urban Airship and Contributors */

#import "UAModifyTagsAction.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UANamedUser.h"

NSString *const UAModifyTagsNamedUserKey = @"named_user";
NSString *const UAModifyTagsChannelKey = @"channel";
NSString *const UAModifyTagsDeviceKey = @"device";

@implementation UAModifyTagsAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    // No background push
    if (arguments.situation == UASituationBackgroundPush) {
        return NO;
    };

    // Single tag
    if ([arguments.value isKindOfClass:[NSString class]]) {
        return YES;
    }

    // Array of tags
    if ([arguments.value isKindOfClass:[NSArray class]]) {
        return [self isTagArrayValid:arguments.value];
    }

    // Tag groups + device tags
    if ([arguments.value isKindOfClass:[NSDictionary class]]) {

        id channelTagGroups = arguments.value[UAModifyTagsChannelKey];
        if (channelTagGroups && ![self areTagGroupsValid:channelTagGroups]) {
            return NO;
        }

        id namedUserTagGroups = arguments.value[UAModifyTagsNamedUserKey];
        if (namedUserTagGroups && ![self areTagGroupsValid:namedUserTagGroups]) {
            return NO;
        }

        id deviceTags = arguments.value[UAModifyTagsDeviceKey];
        if (deviceTags && ![self isTagArrayValid:deviceTags]) {
            return NO;
        }

        // Make sure we have at least 1 tag
        if (deviceTags || channelTagGroups || namedUserTagGroups) {
            return YES;
        }
    }

    return NO;
}


- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    BOOL updateChannelRegistration = NO;
    BOOL updateNamedUser = NO;

    if ([arguments.value isKindOfClass:[NSString class]]) {
        [self applyChannelTags:@[arguments.value]];
        updateChannelRegistration = YES;
    } else if ([arguments.value isKindOfClass:[NSArray class]]) {
        [self applyChannelTags:arguments.value];
        updateChannelRegistration = YES;
    } else if ([arguments.value isKindOfClass:[NSDictionary class]]) {
        id channelTagGroups = arguments.value[UAModifyTagsChannelKey];
        if (channelTagGroups) {
            for (id key in channelTagGroups) {
                [self applyChannelTags:channelTagGroups[key] group:key];
            }
            updateChannelRegistration = YES;
        }

        id namedUserTagGroups = arguments.value[UAModifyTagsNamedUserKey];
        if (namedUserTagGroups) {
            for (id key in namedUserTagGroups) {
                [self applyNamedUserTags:namedUserTagGroups[key] group:key];
            }

            updateNamedUser = YES;
        }

        id deviceTags = arguments.value[UAModifyTagsDeviceKey];
        if (deviceTags) {
            [self applyChannelTags:deviceTags];
            updateChannelRegistration = YES;
        }
    }

    if (updateNamedUser) {
        [[UAirship namedUser] updateTags];
    }

    if (updateChannelRegistration) {
        [[UAirship push] updateRegistration];
    }

    completionHandler([UAActionResult emptyResult]);
}

- (BOOL)areTagGroupsValid:(id)tagGroups {
    if (![tagGroups isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    for (id group in tagGroups) {
        if (![group isKindOfClass:[NSString class]]) {
            return NO;
        }

        if (![self isTagArrayValid:tagGroups[group]]) {
            return NO;
        }
    }

    return YES;
}

- (BOOL)isTagArrayValid:(id)tagArray {
    if (![tagArray isKindOfClass:[NSArray class]]) {
        return NO;
    }

    for (id tag in tagArray) {
        if (![tag isKindOfClass:[NSString class]]) {
            return NO;
        }
    }

    return YES;
}

- (void)applyChannelTags:(NSArray *)tags {}

- (void)applyChannelTags:(NSArray *)tags group:(NSString *)group {}

- (void)applyNamedUserTags:(NSArray *)tags group:(NSString *)group {}

@end
