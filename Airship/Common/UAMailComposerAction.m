/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UAMailComposerAction.h"
#import "UAMailComposerData.h"

NSString * const UAMailComposerActionErrorDomain = @"com.urbanairship.actions.mailcomposer";

@interface UAMailComposerAction()
@property(nonatomic, copy) UAActionCompletionHandler handler;
@property(nonatomic, strong) MFMailComposeViewController *mfViewController;
@end

@implementation UAMailComposerAction

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    self.handler = completionHandler;

    UAMailComposerData *data = arguments.value;

    if ([MFMailComposeViewController canSendMail]) {
		self.mfViewController = [[MFMailComposeViewController alloc] init];

        self.mfViewController.mailComposeDelegate = self;

        UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;

        [self.mfViewController setSubject:data.subject];
        [self.mfViewController setMessageBody:data.body?:@"" isHTML:NO];
        [self.mfViewController setToRecipients:data.recipients];

		[rootViewController presentViewController:self.mfViewController animated:YES completion:nil];

	} else {
        NSError *error = [NSError errorWithDomain:UAMailComposerActionErrorDomain
                                             code:UAMailComposerActionErrorCodeMailDisabled
                                         userInfo:@{NSLocalizedDescriptionKey : @"mail is disabled"}];
        completionHandler([UAActionResult error:error]);
	}
}

- (void)didPerformWithArguments:(UAActionArguments *)arguments withResult:(UAActionResult *)result {
    self.handler = nil;
    self.mfViewController = nil;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    //TODO: handle additional error codes? Is it appropriate to continue if we reach an error here?
    [self.mfViewController dismissViewControllerAnimated:YES completion:nil];
    self.handler([UAActionResult none]);
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    return (BOOL)[arguments.value isKindOfClass:[UAMailComposerData class]];
}

@end
