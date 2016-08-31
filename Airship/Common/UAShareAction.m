/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

@interface UAShareAction()
@property (nonatomic, strong) UAActivityViewController *lastActivityViewController;
@property (nonatomic, strong) UIPopoverController *popoverController;
@end

@implementation UAShareAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    return YES;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    UA_LDEBUG(@"Running share action: %@", arguments);

    NSArray *activityItems = @[arguments.value];

    UAActivityViewController *activityViewController = [[UAActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeSaveToCameraRoll, UIActivityTypeAirDrop, UIActivityTypePostToFacebook];

    UIUserInterfaceIdiom userInterfaceIdiom = [UIDevice currentDevice].userInterfaceIdiom;

    void (^displayShareBlock)(void) = ^(void) {

        self.lastActivityViewController = activityViewController;

        // iOS 8.0+
        if ([activityViewController respondsToSelector:@selector(popoverPresentationController)]) {

            UIPopoverPresentationController * popoverPresentationController = activityViewController.popoverPresentationController;

            popoverPresentationController.permittedArrowDirections = 0;

            // Set the delegate, center the popover on the screen
            popoverPresentationController.delegate = activityViewController;
            popoverPresentationController.sourceRect = activityViewController.sourceRect;
            popoverPresentationController.sourceView = [UAUtils topController].view;

            [[UAUtils topController] presentViewController:activityViewController animated:YES completion:nil];

        } else if (userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            [[UAUtils topController] presentViewController:activityViewController animated:YES completion:nil];
        }
    };


    void (^dismissalBlock)(void);
    __weak UAShareAction *weakSelf = self;

    activityViewController.dismissalBlock = dismissalBlock = ^{
        __strong UAShareAction *strongSelf = weakSelf;

        completionHandler([UAActionResult emptyResult]);

        strongSelf.lastActivityViewController = nil;
        strongSelf.popoverController = nil;
    };

    if (self.lastActivityViewController) {
        self.lastActivityViewController.dismissalBlock = ^{
            dismissalBlock();
            displayShareBlock();
        };

        if (userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            [self.lastActivityViewController dismissViewControllerAnimated:YES completion:nil];
        }
    } else {
        displayShareBlock();
    }
}

@end
