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

#import "UAAction.h"

@class UAInboxMessage;

/**
 * Requests the inbox be displayed.
 *
 * The action will call the UAInboxDelegate or the UAInboxPushHandlerDelegate
 * if the UAInboxDelegate is not available. If the specified message is available
 * showInboxMessage: will be called for every accepted situation except UASituationForegroundPush
 * where richPushMessageAvailable: will be called instead.
 *
 * If the message is unavailable because the message is not in the message list or
 * the message ID was not supplied then showInbox will be called for every situation
 * except for UASituationForegroundPush.
 *
 * This action is registered under the names open_mc_action and ^mc.
 *
 * Expected argument value is an inbox message ID as an NSString, nil, or "auto"
 * to look for the message in the argument's metadata.
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush,
 * UASituationWebViewInvocation, UASituationManualInvocation,
 * and UASituationForegroundInteractiveButton
 *
 * Result value: nil
 */
@interface UADisplayInboxAction : UAAction

@end
