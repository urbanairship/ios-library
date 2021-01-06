/* Copyright Airship and Contributors */

#import "UAModifyAttributesAction.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UANamedUser.h"
#import "UAAttributesActionPredicate+Internal.h"

NSString *const UAModifyAttributesNamedUserKey = @"named_user";
NSString *const UAModifyAttributesChannelKey = @"channel";
NSString *const UAModifyAttributesSetActionKey = @"set";
NSString *const UAModifyAttributesRemoveActionKey = @"remove";

@implementation UAModifyAttributesAction

NSString * const UAModifyAttributesActionDefaultRegistryName = @"modify_attributes_action";
NSString * const UAModifyAttributesActionDefaultRegistryAlias = @"^a";

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    // No background push
    if (arguments.situation == UASituationBackgroundPush) {
        return NO;
    };

    // Channel attributes
    id channelAttributes = arguments.value[UAModifyAttributesChannelKey];
    if (channelAttributes && ![self areAttributeMutationsValid:channelAttributes]) {
        return NO;
    }

    // Named User attributes
    id namedUserAttributes = arguments.value[UAModifyAttributesNamedUserKey];
    if (namedUserAttributes && ![self areAttributeMutationsValid:namedUserAttributes]) {
        return NO;
    }

    if (channelAttributes || namedUserAttributes) {
        return YES;
    }
    
    return NO;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {
    id channelAttributes = arguments.value[UAModifyAttributesChannelKey];
    UAAttributeMutations *channelMutations;
    if (channelAttributes) {
        channelMutations = [self mutationsWithArguments:channelAttributes];
    }
    
    id namedUserAttributes = arguments.value[UAModifyAttributesNamedUserKey];
    UAAttributeMutations *namedUserMutations;
    if (namedUserAttributes) {
        namedUserMutations = [self mutationsWithArguments:namedUserAttributes];
    }
    
    
    if (channelAttributes) {
        [[UAirship channel] applyAttributeMutations:channelMutations];
    }

    if (namedUserAttributes) {
        [[UAirship namedUser] applyAttributeMutations:namedUserMutations];
    }

    completionHandler([UAActionResult emptyResult]);
}

- (UAAttributeMutations *)mutationsWithArguments:(id)args {
    UAAttributeMutations *mutations = [UAAttributeMutations mutations];
    id setAttributeMutations = args[UAModifyAttributesSetActionKey];
    for (id key in setAttributeMutations) {
        if ([setAttributeMutations[key] isKindOfClass:[NSString class]]) {
            [mutations setString:setAttributeMutations[key] forAttribute:key];
        } else if ([setAttributeMutations[key] isKindOfClass:[NSNumber class]]) {
            [mutations setNumber:setAttributeMutations[key] forAttribute:key];
        } else if ([setAttributeMutations[key] isKindOfClass:[NSDate class]]) {
            [mutations setDate:setAttributeMutations[key] forAttribute:key];
        }
    }
    id removeAttributeMutations = args[UAModifyAttributesRemoveActionKey];
    for (id attribute in removeAttributeMutations) {
        [mutations removeAttribute:attribute];
    }
    return mutations;
}

- (BOOL)areAttributeMutationsValid:(id)attributeMutations {
    if (![attributeMutations isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id setAttributeMutations = attributeMutations[UAModifyAttributesSetActionKey];
    if (setAttributeMutations && ![self isSetAttributeMutationValid:setAttributeMutations]) {
        return NO;
    }
    
    id removeAttributeMutations = attributeMutations[UAModifyAttributesRemoveActionKey];
    if (removeAttributeMutations && ![self isRemoveAttributeMutationValid:removeAttributeMutations]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isSetAttributeMutationValid:(id)mutation {
    if (![mutation isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    return YES;
}

- (BOOL)isRemoveAttributeMutationValid:(id)mutation {
    if (![mutation isKindOfClass:[NSArray class]]) {
        return NO;
    }

    return YES;
}

@end
