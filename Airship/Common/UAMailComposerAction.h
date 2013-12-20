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

#import "UAAction.h"
#import <MessageUI/MessageUI.h>

/**
 * Represents the possible error conditions when running a `UAMailComposerAction`.
 */
NS_ENUM(NSInteger, UAMailComposerActionErrorCode) {
    /**
     * Indicates that the mail composer could not be displayed because mail is disabled.
     */
    UAMailComposerActionErrorCodeMailDisabled
};

/**
 * The domain for errors encountered when running a `UAMailComposerAction`.
 */
extern NSString * const UAMailComposerActionErrorDomain;

/**
 * Displays the default mail composer, allowing the user to send a message.
 * The address, subject and body sections of the mail composer may be optionally filled in
 * with default values.
 *
 * Expected argument values: NSDictionary or UAMailComposerData.
 * NSDictionary arguments values must be KVC compliant representations of the `UAMailComposerData` class.
 *
 * Valid situations: `UASituationForegroundPush`, `UASituationLaunchedFromPush`, `UASituationLaunchedFromSpringBoard`,
 * `UASituationRichPush`.
 *
 * Result values: nil, with an additional NSError* in erroneous circumstances.
 */
@interface UAMailComposerAction : UAAction

@end
