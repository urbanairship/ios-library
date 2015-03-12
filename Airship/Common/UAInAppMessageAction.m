
#import "UAInAppMessageAction.h"
#import "UAInAppMessage.h"
#import "UAInAppMessageController.h"
#import "UAGlobal.h"
#import "UAirship.h"
#import "UAPush.h"
#import "UAActionRegistry.h"
#import "UAirship.h"

@interface UAInAppMessageAction ()
@property(nonatomic, strong) UAInAppMessageController *messageController;
@end

@implementation UAInAppMessageAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    BOOL acceptsValue = [arguments.value isKindOfClass:[NSDictionary class]];

    // launching from push is not allowed
    BOOL acceptsSituation = arguments.situation != UASituationLaunchedFromPush;

    return acceptsValue && acceptsSituation;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    if (arguments.situation == UASituationManualInvocation) {
        [self displayMessageWithArguments:arguments];
    } else {
        [self savePendingMessageWithArguments:arguments];
    }

    completionHandler([UAActionResult emptyResult]);
}


/**
 * Helper method to handle displaying the in-app message.
 * @param arguments The action arguments.
 */
- (void)displayMessageWithArguments:(UAActionArguments *)arguments {

    UAInAppMessage *message = [UAInAppMessage messageWithPayload:arguments.value];

    NSDictionary *launchNotification = [UAirship push].launchNotification;

    // If the pending payload ID does not match the launchNotification's send ID
    if ([message.identifier isEqualToString:launchNotification[@"_"]]) {
        UA_LINFO(@"The in-app message delivery push was directly launched for message: %@", message);
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
        return;
    }

    // Check if the message is expired
    if (message.expiry && [[NSDate date] compare:message.expiry] == NSOrderedDescending) {
        UA_LINFO(@"In-app message is expired: %@", message);
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
        return;
    }

    // If it's not currently displayed
    if ([message isEqualToMessage:self.messageController.message]) {
        UA_LDEBUG(@"In-app message already displayed: %@", message);
        return;
    }

    UA_LINFO(@"Displaying in-app message: %@", message);
    UAInAppMessageController *messageController = [[UAInAppMessageController alloc] initWithMessage:message dismissalBlock:^{
        // Delete the pending payload once it's dismissed
        [UAInAppMessage deletePendingMessagePayload:arguments.value];
    }];

    // Dismiss any existing message and show the new one
    [self.messageController dismiss];
    self.messageController = messageController;
    [messageController show];
}

/**
 * Helper method to handle saving the in-app message to display later.
 * @param arguments The action arguments.
 */
- (void)savePendingMessageWithArguments:(UAActionArguments *)arguments {
    // Set the send ID as the IAM unique identifier
    NSDictionary *apnsPayload = arguments.metadata[UAActionMetadataPushPayloadKey];
    NSMutableDictionary *messagePayload = [NSMutableDictionary dictionaryWithDictionary:arguments.value];
    if (apnsPayload[@"_"]) {
        messagePayload[@"identifier"] = apnsPayload[@"_"];
    }

    // Store it for later
    UA_LINFO(@"Storing in-app message to display on next foreground: %@.", messagePayload);
    [UAInAppMessage storePendingMessagePayload:messagePayload];
}

@end
