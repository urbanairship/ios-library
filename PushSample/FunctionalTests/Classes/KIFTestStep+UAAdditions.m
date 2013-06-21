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

#import "KIFTestStep+UAAdditions.h"
#import "UATestPushDelegate.h"
#import "UAUtils.h"

#define kPushWait 90.0

@implementation KIFTestStep (UAAdditions)

+ (id)stepToSetUniqueID:(NSString *)alertID {
    return [KIFTestStep stepWithDescription:@"Set uniqueID." executionBlock:^(KIFTestStep *step, NSError **error) {

        UATestPushDelegate *pushDelegate = (UATestPushDelegate*) [UAPush shared].delegate;
        pushDelegate.uniqueID = alertID;

        return KIFTestStepResultSuccess;
    }];
}

+ (NSArray *) stepsToSendAndWaitForNotification:(NSString *)description sendPushBlock:(SendPushBlock)sendPushBlock {
    NSString *alertID = [UAUtils UUID];

    NSMutableArray *steps = [NSMutableArray array];

    [steps addObject:[KIFTestStep stepToSetUniqueID:alertID]];

    [steps addObject:[KIFTestStep stepWithDescription:description executionBlock:^(KIFTestStep *step, NSError **error) {
        sendPushBlock(alertID);
        return KIFTestStepResultSuccess;
    }]];

    KIFTestStep *waitStep = [KIFTestStep stepToWaitForTappableViewWithAccessibilityLabel:alertID];
    waitStep.timeout = kPushWait;

    [steps addObject:waitStep];
    [steps addObject:[KIFTestStep stepToTapViewWithAccessibilityLabel:alertID traits:UIAccessibilityTraitButton]];

    return steps;
}


@end