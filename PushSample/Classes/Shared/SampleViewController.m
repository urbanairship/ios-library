/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "SampleViewController.h"
#import "UAPush.h"
#import "UAirship.h"
#import "UAPushLocalization.h"
#import "UAPushSettingsViewController.h"
#import "UAPushMoreSettingsViewController.h"

@implementation SampleViewController

- (UAPushSettingsViewController *)buildAPNSSettingsViewController {
    UAPushSettingsViewController *vc = [[UAPushSettingsViewController alloc] initWithNibName:@"UAPushSettingsView"
                                                                                      bundle:nil];

    vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                         action:@selector(closeSettings)];

    return vc;
}

- (UAPushMoreSettingsViewController *)buildTokenSettingsViewController {
    UAPushMoreSettingsViewController *vc = [[UAPushMoreSettingsViewController alloc] initWithNibName:@"UAPushMoreSettingsView"
                                                                                              bundle:nil];
    vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                              target:self
                                            action:@selector(closeSettings)];

    return vc;
}

- (IBAction)buttonPressed:(id)sender {
    UIViewController *root;
    if (sender == self.settingsButton) {
        root = [self buildAPNSSettingsViewController];
    } else if (sender == self.tokenButton) {
        root = [self buildTokenSettingsViewController];
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];

    [self presentViewController:nav animated:YES completion:nil];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
