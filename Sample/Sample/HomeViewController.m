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

// Import the Urban Airship umbrella header using the framework
#import <AirshipKit/AirshipKit.h>
#import "HomeViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshView) name:@"channelIDUpdated" object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [self refreshView];
}

- (IBAction)buttonTapped:(id)sender {
    if (sender == self.enablePushButton) {
        [UAirship push].userPushNotificationsEnabled = YES;
    }

    if (sender == self.channelIDButton && [UAirship push].channelID) {
        [UIPasteboard generalPasteboard].string = [UAirship push].channelID;
        UAInAppMessage *message = [[UAInAppMessage alloc] init];
        message.alert = NSLocalizedStringFromTable(@"UA_Copied_To_Clipboard", @"UAPushUI", @"Copied to clipboard string");
        message.position = UAInAppMessagePositionTop;
        message.duration = 1.5;
        message.primaryColor = [UIColor colorWithRed:255/255.f green:200/255.f blue:40/255.f alpha:1];
        message.secondaryColor = [UIColor colorWithRed:0/255.f green:105/255.f blue:143/255.f alpha:1];
        [[UAirship inAppMessaging] displayMessage:message];
    }
}

- (void)refreshView {
    if ([UAirship push].userPushNotificationsEnabled) {
        [self.channelIDButton setTitle:[UAirship push].channelID forState:UIControlStateNormal];
        self.channelIDButton.hidden = NO;
        self.enablePushButton.hidden = YES;
        return;
    }
    self.channelIDButton.hidden = YES;
    self.enablePushButton.hidden = NO;
}

@end
