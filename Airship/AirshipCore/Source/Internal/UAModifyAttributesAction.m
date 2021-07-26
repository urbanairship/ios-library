/* Copyright Airship and Contributors */

#import "UAModifyAttributesAction.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UAAttributesActionPredicate+Internal.h"
#import "UAActionArguments.h"
#import "UAActionResult.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

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
    if (channelAttributes) {
        UAAttributeMutations *channelMutations = [self mutationsWithArguments:channelAttributes];
        [[UAirship channel] applyAttributeMutations:channelMutations];
    }
    
    id namedUserAttributes = arguments.value[UAModifyAttributesNamedUserKey];
    if (namedUserAttributes) {
        [self applyEdits:[UAirship contact].editAttibutes attributes:namedUserAttributes];
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

- (void)applyEdits:(UAAttributesEditor *)editor attributes:(id)args {
    id setAttributeMutations = args[UAModifyAttributesSetActionKey];
    for (id key in setAttributeMutations) {
        if ([setAttributeMutations[key] isKindOfClass:[NSString class]]) {
            [editor setString:setAttributeMutations[key] attribute:key];
        } else if ([setAttributeMutations[key] isKindOfClass:[NSNumber class]]) {
            [editor setNumber:setAttributeMutations[key] attribute:key];
        } else if ([setAttributeMutations[key] isKindOfClass:[NSDate class]]) {
            [editor setDate:setAttributeMutations[key] attribute:key];
        }
    }
    id removeAttributeMutations = args[UAModifyAttributesRemoveActionKey];
    for (id attribute in removeAttributeMutations) {
        [editor removeAttribute:attribute];
    }

    [editor apply];
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
