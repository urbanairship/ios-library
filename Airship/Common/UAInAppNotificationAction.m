
#import "UAInAppNotificationAction.h"
#import "UAInAppNotification.h"
#import "UAInAppNotificationController.h"
#import "UAGlobal.h"
#import "UAPush.h"
#import "UAActionRegistry.h"

@interface UAInAppNotificationAction ()
@property(nonatomic, strong) UAInAppNotificationController *notificationController;
@end

@implementation UAInAppNotificationAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    BOOL acceptsValue = [arguments.value isKindOfClass:[NSDictionary class]];

    // launching from push is not allowed
    BOOL acceptsSituation = arguments.situation != UASituationLaunchedFromPush;

    return acceptsValue && acceptsSituation;
}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)name
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSDictionary *payload = arguments.value;

    if (arguments.situation == UASituationManualInvocation) {
        // the IAN payload is indexed to the corresponding action name
        NSString *ianPayloadKey = kUAInAppNotificationActionDefaultRegistryName;

        // the IAN associated with the launch notification, if present
        NSDictionary *launchIANPayload = [[UAPush shared].launchNotification objectForKey:ianPayloadKey];

        // if the pending payload isn't contained in the launch notification
        if (![payload isEqualToDictionary:launchIANPayload]) {
            UAInAppNotification *n = [UAInAppNotification notificationWithPayload:arguments.value];

            // if there is no expiry or expiry is in the future
            if (!n.expiry || [[NSDate date] compare:n.expiry] == NSOrderedAscending) {
                // display it
                UAInAppNotificationController *notificationController = [[UAInAppNotificationController alloc] initWithNotification:n];
                [self.notificationController dismiss];
                self.notificationController = notificationController;
                [notificationController show];
            } else {
                UA_LDEBUG(@"In-app notification is expired: %@", n.expiry);
            }
        } else {
            UA_LDEBUG(@"In-app notification matches launch payload, discarding: %@", launchIANPayload);
        }

    } else {
        // store it for later
        NSDictionary *parentDictionary = arguments.metadata[UAActionMetadataPushPayloadKey];
        NSString *sendID = parentDictionary[@"_"];
        NSMutableDictionary *amendedPayload = [NSMutableDictionary dictionaryWithDictionary:payload];
        if (sendID) {
            amendedPayload[@"identifier"] = sendID;
        }
        [UAInAppNotification storePendingNotificationPayload:payload];
    }

    completionHandler([UAActionResult emptyResult]);
}

@end
