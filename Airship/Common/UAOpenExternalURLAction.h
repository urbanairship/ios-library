/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

/**
 * Represents the possible error conditions
 * when running a `UAOpenExternalURLAction`.
 */
typedef NS_ENUM(NSInteger, UAOpenExternalURLActionErrorCode) {
    /**
     * Indicates that the URL failed to open.
     */
    UAOpenExternalURLActionErrorCodeURLFailedToOpen
};

/**
 * The domain for errors encountered when running a `UAOpenExternalURLAction`.
 */
extern NSString * const UAOpenExternalURLActionErrorDomain;

/**
 * Opens a URL, either in safari or using custom URL schemes. This action is 
 * registered under the names ^u and open_external_url_action.
 *
 * Expected argument values: NSString
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegoundInteractiveButton, and
 * UASituationManualInvocation
 *
 * Result value: An NSString representation of the input
 *
 * Error: `UAOpenExternalURLActionErrorCodeURLFailedToOpen` if the URL could not be opened
 *
 * Fetch result: UAActionFetchResultNone
 */
@interface UAOpenExternalURLAction : UAAction

@end
