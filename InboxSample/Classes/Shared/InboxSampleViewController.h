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

#import <UIKit/UIKit.h>

@class UAInboxMessage;

@interface InboxSampleViewController : UIViewController <UIActionSheetDelegate, UIPopoverControllerDelegate>


- (IBAction)mail:(id)sender;
- (IBAction)selectInboxStyle:(id)sender;

/**
 * The label displaying the current version number of the Urban
 * Airship library.
 */
@property(nonatomic, weak) IBOutlet UILabel *version;

/**
 * Whether to display incoming rich push messages in
 * an overlay controller.
 *
 * Defaults to YES.
 */
@property(nonatomic, assign) BOOL useOverlay;

/**
 * Whether to use the iPhone UI on the iPad. 
 *
 * Defaults to NO.
 */
@property(nonatomic, assign) BOOL runiPhoneTargetOniPad;

/**
 * The size of the popover controller's window,
 * When using the popover user interface.
 *
 * Defaults to 320 x 1100.
 */
@property(nonatomic, assign) CGSize popoverSize;

/*
 * Displays an incoming message, either by showing it in an overlay,
 * or loading it in an already visible inbox interface.
 *
 * @param message The message to display.
 */
- (void)displayMessage:(UAInboxMessage *)message;

@end

