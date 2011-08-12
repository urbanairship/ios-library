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

#import "UAInboxNavUI.h"
#import "UAInboxUI.h"

@implementation InboxSampleViewController

@synthesize version;

- (IBAction)mail:(id)sender {
    [UAInbox useCustomUI:[UAInboxNavUI class]];
    [UAInbox displayInbox:self.navigationController animated:YES];   
}

- (IBAction)launchModalInbox:(id)sender {
    
    [UAInbox useCustomUI:[UAInboxUI class]];
    [UAInbox displayInbox:self.navigationController animated:YES];   
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.version.text = [NSString stringWithFormat:@"UAInbox Version: %@", [UAInboxVersion get]];
    
    self.navigationItem.rightBarButtonItem 
        = [[[UIBarButtonItem alloc] initWithTitle:@"Inbox" style:UIBarButtonItemStylePlain target:self action:@selector(mail:)] autorelease];
    
    // For UINavigationController UI
    [UAInboxNavUI shared].popoverButton = self.navigationItem.rightBarButtonItem;
    
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    RELEASE_SAFELY(version);
    [super dealloc];
}

@end
