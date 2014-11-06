/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAShareAction.h"
#import "UAUtils.h"
#import "UAGlobal.h"
#import "UAActivityViewController.h"
#import "UAPopoverPositioner.h"

@interface UAShareAction()
/**
 * A set of positioners, in case the action is run multiple times between dismissals.
 */
@property(nonatomic, strong) NSMutableSet *positioners;
@end

@implementation UAShareAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    IF_IOS7_OR_GREATER(return YES;)

    // Reject if on iOS 6.x (unsupported).
    return NO;

}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)actionName
           completionHandler:(UAActionCompletionHandler)completionHandler {

    UA_LDEBUG(@"Running share action: %@", arguments);

    NSArray *activityItems = @[arguments.value];

    UAActivityViewController *activityViewController =  [[UAActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeSaveToCameraRoll, UIActivityTypeAirDrop];

    // A popover positioner, if we need it
    UAPopoverPositioner *positioner;

    // iOS 8.0+, iPad only
    if ([activityViewController respondsToSelector:@selector(popoverPresentationController)]) {

        UIPopoverPresentationController * popoverPresentationController = activityViewController.popoverPresentationController;

        popoverPresentationController.permittedArrowDirections = 0;

        // Create and add a positioner
        positioner = [[UAPopoverPositioner alloc] init];
        [self.positioners addObject:positioner];

        // Set the new positioner as the delegate, center the popover on the screen
        popoverPresentationController.delegate = positioner;
        popoverPresentationController.sourceRect = [positioner sourceRect];
        popoverPresentationController.sourceView = [UAUtils topController].view;
    }

    // Remove the positioner, if present, and call the completion handler once the modal is dismissed
    activityViewController.dismissalBlock = ^ {
        [self.positioners removeObject:positioner];
        completionHandler([UAActionResult emptyResult]);
    };

    [[UAUtils topController] presentViewController:activityViewController animated:YES completion:nil];
}

@end
