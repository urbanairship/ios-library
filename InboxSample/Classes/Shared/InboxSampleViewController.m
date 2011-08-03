/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
#import "InboxSampleViewController.h"
#import "InboxSampleAppDelegate.h"
#import "UAirship.h"
#import "UAInbox.h"
#import "UAInboxMessageListController.h"
#import "UAInboxMessageViewController.h"

@implementation InboxSampleViewController

@synthesize version, isShowingInbox, nav;


- (void)showInboxWithMessage:(NSString *)messageID {
    
    if (!isShowingInbox) {
        
        self.isShowingInbox = YES;
    
        UAInboxMessageListController *mlc = [[[UAInboxMessageListController alloc] initWithNibName:@"UAInboxMessageListController" bundle:nil] autorelease];
        
        mlc.title = @"Inbox";
        mlc.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                              target:self 
                                                                                              action:@selector(inboxDone:)]autorelease];
        
        self.nav = [[[UINavigationController alloc] initWithRootViewController:mlc] autorelease];
        
        if(messageID) {
            UAInboxMessageViewController *mvc = [[[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil] autorelease];
            [mvc loadMessageForID:messageID];
            [nav pushViewController:mvc animated:NO];
        }
        
        [self presentModalViewController:nav animated:YES];
    
    }
    
    else {
        if ([nav.topViewController class] == [UAInboxMessageViewController class]) {
            [(UAInboxMessageViewController *)nav.topViewController loadMessageForID:messageID];
        } else {
            UAInboxMessageViewController *mvc = [[[UAInboxMessageViewController alloc] initWithNibName:@"UAInboxMessageViewController" bundle:nil] autorelease];
            [mvc loadMessageForID:messageID];
            [nav pushViewController:mvc animated:YES];
        }
    }
    
}

- (void)showInbox {
    [self showInboxWithMessage:nil];
}

- (void)inboxDone:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
    self.isShowingInbox = NO;
}

-(IBAction)mail:(id)sender {
    [self showInbox];   
}

//<UAInboxUIDelegate>
- (void)displayMessage:(NSString *)messageID {
    [self showInboxWithMessage:messageID];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.version.text = [NSString stringWithFormat:@"UAInbox Version: %@", [UAInboxVersion get]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    RELEASE_SAFELY(version);
    self.nav = nil;
    [super dealloc];
}

@end
