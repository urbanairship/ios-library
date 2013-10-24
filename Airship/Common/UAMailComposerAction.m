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

@interface UAMailComposerActionController : NSObject<MFMailComposeViewControllerDelegate>

- (void)displayWithData:(UAMailComposerData *)data withHandler:(UAActionCompletionHandler)handler;

@property(nonatomic, copy) UAActionCompletionHandler handler;
@property(nonatomic, strong) MFMailComposeViewController *mfViewController;
@end

@implementation UAMailComposerActionController

- (void)displayWithData:(UAMailComposerData *)data withHandler:(UAActionCompletionHandler)handler {
    if ([MFMailComposeViewController canSendMail]) {
		self.mfViewController = [[MFMailComposeViewController alloc] init];

        __weak id weakSelf = self;
        self.mfViewController.mailComposeDelegate = weakSelf;

        UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;

        [self.mfViewController setSubject:data.subject];
        [self.mfViewController setMessageBody:data.body?:@"" isHTML:NO];
        [self.mfViewController setToRecipients:data.recipients];

		[rootViewController presentViewController:self.mfViewController animated:YES completion:nil];

	} else {
        NSError *error = [NSError errorWithDomain:UAMailComposerActionErrorDomain
                                             code:UAMailComposerActionErrorCodeMailDisabled
                                         userInfo:@{NSLocalizedDescriptionKey : @"mail is disabled"}];
        self.handler([UAActionResult error:error]);
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error {
    //TODO: handle additional error codes? Is it appropriate to continue if we reach an error here?
    [self.mfViewController dismissViewControllerAnimated:YES completion:nil];
    self.handler([UAActionResult none]);
}

@end

@interface UAMailComposerAction()
@property(nonatomic, strong) NSMutableArray *controllers;
@end


@implementation UAMailComposerAction

- (id)init {
    self = [super init];
    if (self) {
        self.controllers = [NSMutableArray array];
    }
    return self;
}

- (void)performWithArguments:(UAActionArguments *)arguments
       withCompletionHandler:(UAActionCompletionHandler)completionHandler {

    UAMailComposerActionController *controller = [[UAMailComposerActionController alloc] init];
    __weak UAMailComposerAction *weakSelf = self;
    __weak UAMailComposerActionController *weakController = controller;

    [self.controllers addObject:controller];

    controller.handler = ^(UAActionResult *result){
        [weakSelf.controllers removeObject:weakController];
        completionHandler(result);
    };

    UAMailComposerData *data = arguments.value;
    [controller displayWithData:data withHandler:completionHandler];
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    return (BOOL)[arguments.value isKindOfClass:[UAMailComposerData class]];
}

@end
