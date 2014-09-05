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

#import "UAInbox.h"
#import "UAInboxMessageViewController.h"
#import "UAInboxLocalization.h"
#import "UAInboxMessageList.h"

#import "UIWebView+UAAdditions.h"
#import "UAWebViewTools.h"

#import "UAUtils.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UAInboxMessageViewController ()

- (void)refreshHeader;
- (void)updateMessageNavButtons;


@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activity;
@property (nonatomic, weak) IBOutlet UIView *statusBar;
@property (nonatomic, weak) IBOutlet UILabel *statusBarTitle;

@property (nonatomic, strong) UIBarButtonItem *upButtonItem;
@property (nonatomic, strong) UIBarButtonItem *downButtonItem;

@property (nonatomic, strong) NSArray *messages;

/**
 * The UIWebView used to display the message content.
 */
@property (nonatomic, strong) UIWebView *webView;
@end

@implementation UAInboxMessageViewController



- (void)dealloc {
    self.webView.delegate = nil;

}

- (instancetype)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
        
        self.title = UAInboxLocalizedString(@"UA_Message");

        self.upButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:103/* system 'up' bitmap */
                                                                          target:self
                                                                          action:@selector(navigationAction:)];
        self.downButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:104/* system 'down' bitmap */
                                                                            target:self
                                                                            action:@selector(navigationAction:)];
        self.navigationItem.rightBarButtonItems = @[self.upButtonItem, self.downButtonItem];

        self.shouldShowAlerts = YES;

        // make our existing layout work in iOS7
        if ([self respondsToSelector:NSSelectorFromString(@"edgesForExtendedLayout")]) {
            self.edgesForExtendedLayout = UIRectEdgeNone;
            self.navigationController.navigationBar.translucent = NO;
            self.navigationController.navigationBar.opaque = YES;
        }

        self.messages = [UAInbox shared].messageList.messages;
    }


    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.webView setDataDetectorTypes:UIDataDetectorTypeAll];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageListUpdated)
                                                 name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UAInboxMessageListUpdatedNotification object:nil];
}

#pragma mark -
#pragma mark UI

- (void)refreshHeader {
    NSUInteger count = [self.messages count];
    NSUInteger index = [self.messages indexOfObject:self.message];

    if (index < count) {
        self.title = [NSString stringWithFormat:UAInboxLocalizedString(@"UA_Message_Fraction"), index+1, count];
    } else {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
        self.statusBar.hidden = YES;
        self.title = @"";
    }

    [self updateMessageNavButtons];
}

- (void)loadMessageForID:(NSString *)mid {
    NSUInteger index = NSNotFound;

    for (NSUInteger i = 0; i < [self.messages count]; i++) {
        UAInboxMessage *message = [self.messages objectAtIndex:i];
        if ([message.messageID isEqualToString:mid]) {
            index = i;
            break;
        }
    }

    if (index == NSNotFound) {
        UALOG(@"Can not find message with ID: %@", mid);
        return;
    }

    [self loadMessageAtIndex:index];
}

- (void)loadMessageAtIndex:(NSUInteger)index {
    [self.webView stopLoading];
    [self.webView removeFromSuperview];
    self.webView.delegate = nil;

    self.webView = [[UIWebView alloc] init];
    self.webView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    self.webView.delegate = self;

    [self.view insertSubview:self.webView belowSubview:self.statusBar];

    self.message = [self.messages objectAtIndex:index];
    if (self.message == nil) {
        UALOG(@"Can not find message with index: %lu", (unsigned long)index);
        return;
    }

    [self refreshHeader];

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL: self.message.messageBodyURL];
    
    [requestObj setTimeoutInterval:60];
    
    NSString *auth = [UAUtils userAuthHeaderString];
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];

    [self.webView loadRequest:requestObj];
}


#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return [UAWebViewTools webView:wv shouldStartLoadWithRequest:request navigationType:navigationType message:self.message];
}

- (void)webViewDidStartLoad:(UIWebView *)wv {
    [self.statusBar setHidden: NO];
    [self.activity startAnimating];
    self.statusBarTitle.text = self.message.title;
    
    [self.webView populateJavascriptEnvironment:self.message];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {
    [self.statusBar setHidden: YES];
    [self.activity stopAnimating];

    // Mark message as read after it has finished loading
    if(self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }

    [self.webView fireUALibraryReadyEvent];
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    [self.statusBar setHidden: YES];
    [self.activity stopAnimating];

    if (error.code == NSURLErrorCancelled)
        return;
    UALOG(@"Failed to load message: %@", error);
    
    if (self.shouldShowAlerts) {
        
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:UAInboxLocalizedString(@"UA_Mailbox_Error_Title")
                                                            message:UAInboxLocalizedString(@"UA_Error_Fetching_Message")
                                                           delegate:self
                                                  cancelButtonTitle:UAInboxLocalizedString(@"UA_OK")
                                                  otherButtonTitles:nil];
        [someError show];
    }
}

#pragma mark UARichContentWindow

- (void)closeWindow:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
}

#pragma mark Message Nav

- (IBAction)navigationAction:(id)sender {

    NSUInteger index = [self.messages indexOfObject:self.message];

    if (self.upButtonItem == sender) {
        [self loadMessageAtIndex:index-1];
    } else if(self.downButtonItem == sender) {
        [self loadMessageAtIndex:index+1];
    }
}

- (void)updateMessageNavButtons {
    NSUInteger index = [self.messages indexOfObject:self.message];

    if (!self.message || index == NSNotFound) {
        self.upButtonItem.enabled = NO;
        self.downButtonItem.enabled = NO;
    } else {
        self.upButtonItem.enabled = (index > 0);
        self.downButtonItem.enabled = (index < ([self.messages count] - 1));
    }

    UALOG(@"update nav %lu, of %lu", (unsigned long)index, (unsigned long)[[UAInbox shared].messageList messageCount]);
}

#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {
    // Refresh the message array
    self.messages = [UAInbox shared].messageList.messages;

    // Refresh the new instance of the current message
    NSString *messageID = self.message.messageID;
    self.message = nil;
    if (messageID) {
        for (UAInboxMessage *message in self.messages) {
            if ([message.messageID isEqualToString:messageID]) {
                self.message = message;
                break;
            }
        }
    }

    [self refreshHeader];
}

@end
