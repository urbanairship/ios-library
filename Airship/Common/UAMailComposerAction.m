
#import "UAMailComposerAction.h"
#import "UAMailComposerData.h"

@interface UAMailComposerAction()
@property(nonatomic, copy) UAActionCompletionHandler handler;
@property(nonatomic, strong) UAActionResult *result;
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
        self.result = [UAActionResult none];

	} else {
        NSError *error = [NSError errorWithDomain:@"whatever" code:0 userInfo:nil];
		self.result = [UAActionResult error:error];
        completionHandler(self.result);
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self.mfViewController dismissViewControllerAnimated:YES completion:nil];
    self.handler(self.result);
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    return (BOOL)[arguments.value isKindOfClass:[UAMailComposerData class]];
}

- (void)dealloc {
    NSLog(@"goooooooood bye");
}

@end
