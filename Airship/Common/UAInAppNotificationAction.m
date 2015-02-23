
#import "UAInAppNotificationAction.h"
#import "UAInAppNotification.h"
#import "UAInAppNotificationController.h"

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
        // display it
        UAInAppNotification *n = [UAInAppNotification notificationWithPayload:arguments.value];
        UAInAppNotificationController *notificationController = [[UAInAppNotificationController alloc] initWithNotification:n];

        [self.notificationController dismiss];
        self.notificationController = notificationController;
        [notificationController show];

        completionHandler([UAActionResult emptyResult]);
    } else {
        // store it for later
        [UAInAppNotification storePendingNotificationPayload:payload];
    }
}

@end
