/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UADefaultMessageCenterMessageViewController.h"
#import "UAWebViewDelegate.h"
#import "UAInbox.h"
#import "UAirship.h"
#import "UAInboxMessageList.h"
#import "UAInboxMessage.h"
#import "UAUtils.h"
#import "UIWebView+UAAdditions.h"
#import "UAMessageCenterLocalization.h"

#define kMessageUp 0
#define kMessageDown 1

@interface UADefaultMessageCenterMessageViewController ()

@property (nonatomic, strong) UAWebViewDelegate *webViewDelegate;

/**
 * The UIWebView used to display the message content.
 */
@property (nonatomic, strong) UIWebView *webView;

/**
 * The index of the currently displayed message.
 */
@property (nonatomic, assign) NSUInteger messageIndex;

/**
 * The view displayed when there are no messages.
 */
@property (nonatomic, weak) IBOutlet UIView *coverView;

/**
 * The label displayed in the coverView.
 */
@property (nonatomic, weak) IBOutlet UILabel *coverLabel;

/**
 * Convenience accessor for the messages currently available for display.
 */
@property (nonatomic, readonly) NSArray *messages;

@end

@implementation UADefaultMessageCenterMessageViewController

- (void)dealloc {
    self.webView.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.webViewDelegate = [[UAWebViewDelegate alloc] init];
    self.webViewDelegate.forwardDelegate = self;
    self.webViewDelegate.richContentWindow = self;
    self.webView.delegate = self.webViewDelegate;

    // Allow the webView to detect data types (e.g. phone numbers, addresses) at will
    [self.webView setDataDetectorTypes:UIDataDetectorTypeAll];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:UAMessageCenterLocalizedString(@"ua_delete")
                                                                               style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(delete:)];

    self.coverLabel.text = UAMessageCenterLocalizedString(@"ua_message_not_selected");

    if (self.message) {
        [self loadMessageForID:self.message.messageID];
    } else {
        [self cover];
    }
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

// Note: since the message list is refreshed with new model objects when reloaded,
// we can't reliably hold onto any single instance. This method is mostly for convenience.
- (NSArray *)messages {
    NSArray *allMessages = [UAirship inbox].messageList.messages;
    if (self.filter) {
        return [allMessages filteredArrayUsingPredicate:self.filter];
    } else {
        return allMessages;
    }
}

#pragma mark -
#pragma mark UI

- (void)delete:(id)sender {
    if (self.message) {
        [[UAirship inbox].messageList markMessagesDeleted:@[self.message] completionHandler:nil];
    }
}

- (void)cover {
    self.title = nil;
    self.coverView.hidden = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)uncover {
    self.coverView.hidden = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
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
    self.messageIndex = index;

    [self.webView stopLoading];

    self.message = [self.messages objectAtIndex:index];
    if (self.message == nil) {
        UALOG(@"Unable to find message with index: %lu", (unsigned long)index);
        return;
    }

    [self uncover];
    self.title = self.message.title;

    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL:self.message.messageBodyURL];
    requestObj.timeoutInterval = 60;

    NSString *auth = [UAUtils userAuthHeaderString];
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];

    [self.webView loadRequest:requestObj];
}

- (void)displayAlert:(BOOL)retry {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:UAMessageCenterLocalizedString(@"ua_connection_error")
                                                                   message:UAMessageCenterLocalizedString(@"ua_mc_failed_to_load")
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_ok")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    
    [alert addAction:defaultAction];

    if (retry) {
        UIAlertAction *retryAction = [UIAlertAction actionWithTitle:UAMessageCenterLocalizedString(@"ua_retry_button")
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * _Nonnull action) {
                                                                [self loadMessageAtIndex:self.messageIndex];
        }];

        [alert addAction:retryAction];
    }

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)wv {

    NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:wv.request];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)cachedResponse.response;
    NSInteger status = httpResponse.statusCode;
    NSString *blank = @"about:blank";

    // If the server returns something in the error range, load a blank page
    if (status >= 400 && status <= 599) {
        [wv loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:blank]]];
        if (status >= 500) {
            // Display a retry alert
            [self displayAlert:YES];
        } else {
            // Display a generic alert
            [self displayAlert:NO];
        }
        return;
    } else if ([wv.request.URL.absoluteString isEqualToString:blank]) {
        return;
    }

    // Mark message as read after it has finished loading
    if (self.message.unread) {
        [self.message markMessageReadWithCompletionHandler:nil];
    }

    [self.webView injectInterfaceOrientation:(UIInterfaceOrientation)[[UIDevice currentDevice] orientation]];
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled)
        return;
    UALOG(@"Failed to load message: %@", error);
    [self displayAlert:YES];
}

#pragma mark UARichContentWindow

- (void)closeWebView:(UIWebView *)webView animated:(BOOL)animated {
    if (self.closeBlock) {
        self.closeBlock(animated);
    }
}

#pragma mark NSNotificationCenter callbacks

- (void)messageListUpdated {

    if (self.messages.count) {
        // If the index path is still accessible,
        // find the nearest accessible neighbor
        NSUInteger index = MIN(self.messages.count - 1, self.messageIndex);

        UAInboxMessage *currentMessageAtIndex = [self.messages objectAtIndex:index];

        if (self.message) {
            // if the index has changed
            if (![self.message.messageID isEqual:currentMessageAtIndex.messageID]) {
                // reload the message at that index
                [self loadMessageAtIndex:index];
            } else {
                // refresh the stored instance
                self.message = currentMessageAtIndex;
            }
        }

    } else {
        // There are no more messages to display, so cover up the UI.
        self.message = nil;
        [self cover];
    }
}

@end
