
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

    NSDictionary *payload = arguments.value;

    if (arguments.situation == UASituationManualInvocation) {
        // the IAM payload is indexed to the corresponding action name
        NSString *iamPayloadKey = kUAInAppMessageActionDefaultRegistryName;

        // the IAM associated with the launch notification, if present
        NSDictionary *launchIAMPayload = [[UAirship push].launchNotification objectForKey:iamPayloadKey];

        // if the pending payload isn't contained in the launch notification
        if (![payload isEqualToDictionary:launchIAMPayload]) {
            UAInAppMessage *message = [UAInAppMessage messageWithPayload:arguments.value];

            // if there is no expiry or expiry is in the future
            if (!message.expiry || [[NSDate date] compare:message.expiry] == NSOrderedAscending) {

                // if it's not currently displayed
                if (![message isEqualToMessage:self.messageController.message]) {
                    UAInAppMessageController *messageController = [[UAInAppMessageController alloc] initWithMessage:message dismissalBlock:^{
                        // delete the pending payload once it's dismissed
                        [UAInAppMessage deletePendingMessagePayload:payload];
                    }];

                    // dismiss any existing message and show the new one
                    [self.messageController dismiss];
                    self.messageController = messageController;
                    [messageController show];
                } else {
                    completionHandler([UAActionResult emptyResult]);
                }
            } else {
                UA_LDEBUG(@"In-app message is expired: %@", message.expiry);
            }
        } else {
            UA_LDEBUG(@"In-app message matches launch payload, discarding: %@", launchIAMPayload);
        }

    } else {
        // store it for later
        NSDictionary *parentDictionary = arguments.metadata[UAActionMetadataPushPayloadKey];
        NSString *sendID = parentDictionary[@"_"];
        NSMutableDictionary *amendedPayload = [NSMutableDictionary dictionaryWithDictionary:payload];
        // set the send ID as the IAM unique identifier
        if (sendID) {
            amendedPayload[@"identifier"] = sendID;
        }

        [UAInAppMessage storePendingMessagePayload:amendedPayload];

        completionHandler([UAActionResult emptyResult]);
    }
}

@end
