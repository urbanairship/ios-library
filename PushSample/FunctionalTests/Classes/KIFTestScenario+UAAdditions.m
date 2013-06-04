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

#import "KIFTestScenario+UAAdditions.h"

#import "KIFTestStep.h"

#import "UAPush.h"
#import "UAUtils.h"
#import "UAPushClient.h"

#define kRegistrationWait 30.0
#define kPushWait 60.0

@implementation KIFTestScenario (UAAdditions)

+ (id)scenarioToEnablePush {
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that push is can be enabled in the settings screen."];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Push Settings"]];
    [scenario addStep:[KIFTestStep stepToSetOn:YES forSwitchWithAccessibilityLabel:@"Push Notifications Enabled"]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    //TODO: verify that UAPush thinks push is enabled

    return scenario;

}

+ (id)scenarioToReceiveUnicastPush {

    NSString *alertID = [UAUtils UUID];

    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a unicast push is received and properly handled."];

    [scenario addStep:[KIFTestStep stepWithDescription:@"Send a unicast push." executionBlock:^(KIFTestStep *step, NSError **error) {
        [UAPushClient sendAlert:alertID toDeviceToken:[UAPush shared].deviceToken];
        return KIFTestStepResultSuccess;
    }]];

    KIFTestStep *waitStep = [KIFTestStep stepToWaitForTappableViewWithAccessibilityLabel:alertID];
    waitStep.timeout = kPushWait;//TODO: abstract to pushWait step
    [scenario addStep:waitStep];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:alertID traits:UIAccessibilityTraitButton]];

    return scenario;
}

+ (id)scenarioToReceiveBroadcastPush {
    NSString *alertID = [UAUtils UUID];

    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a broadcast push is received and properly handled."];

    [scenario addStep:[KIFTestStep stepWithDescription:@"Send a broadcast push." executionBlock:^(KIFTestStep *step, NSError **error) {
        [UAPushClient sendBroadcastAlert:alertID];
        return KIFTestStepResultSuccess;
    }]];

    KIFTestStep *waitStep = [KIFTestStep stepToWaitForTappableViewWithAccessibilityLabel:alertID];
    waitStep.timeout = kPushWait;//TODO: abstract to pushWait step
    [scenario addStep:waitStep];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:alertID traits:UIAccessibilityTraitButton]];

    return scenario;
}

+ (id)scenarioToSetAlias {

    NSString *uniqueID = [UAUtils UUID];

    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that an alias can be set and we can receive a push"];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Token Settings"]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Alias"]];

    [scenario addStep:[KIFTestStep stepToEnterText:uniqueID intoViewWithAccessibilityLabel:@"Edit Alias"]];
    
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    [scenario addStep:[KIFTestStep stepToWaitForTimeInterval:kRegistrationWait description:@"Wait for the registration to succeed."]];

    // Now send it a push!

    [scenario addStep:[KIFTestStep stepWithDescription:@"Send an alias push." executionBlock:^(KIFTestStep *step, NSError **error) {
        [UAPushClient sendAlert:uniqueID toAlias:uniqueID];
        return KIFTestStepResultSuccess;
    }]];

    KIFTestStep *waitStep = [KIFTestStep stepToWaitForTappableViewWithAccessibilityLabel:uniqueID];
    waitStep.timeout = kPushWait;
    [scenario addStep:waitStep];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:uniqueID traits:UIAccessibilityTraitButton]];


    return scenario;
}

+ (id)scenarioToSetTag {
    KIFTestScenario *scenario = [KIFTestScenario scenarioWithDescription:@"Test that a tag can be set."];

    NSString *uniqueID = [UAUtils UUID];

    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Token Settings"]];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Tags"]];



    for (NSString *tag in [UAPush shared].tags) {
        [scenario addStep:
            [KIFTestStep stepToTapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Delete %@", tag]
                                                      traits:UIAccessibilityTraitButton]];
        [scenario addStep:
         [KIFTestStep stepToTapViewWithAccessibilityLabel:[NSString stringWithFormat:@"Confirm Deletion for %@", tag]
                                                   traits:UIAccessibilityTraitButton]];
    }

    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Add" traits:UIAccessibilityTraitButton]];

    [scenario addStep:[KIFTestStep stepToEnterText:uniqueID intoViewWithAccessibilityLabel:@"Custom Tag Input"]];

    // save the tag
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // todo: verify that the tag exists

    // back to token screen
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Back" traits:UIAccessibilityTraitButton]];

    // back to main screen
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:@"Done" traits:UIAccessibilityTraitButton]];

    // wait for registration
    [scenario addStep:[KIFTestStep stepToWaitForTimeInterval:kRegistrationWait description:@"Wait for the registration to succeed."]];

    // Now send it a push!

    [scenario addStep:[KIFTestStep stepWithDescription:@"Send a tag push." executionBlock:^(KIFTestStep *step, NSError **error) {
        [UAPushClient sendAlert:uniqueID toTag:uniqueID];
        return KIFTestStepResultSuccess;
    }]];

    KIFTestStep *waitStep = [KIFTestStep stepToWaitForTappableViewWithAccessibilityLabel:uniqueID];
    waitStep.timeout = kPushWait;
    [scenario addStep:waitStep];
    [scenario addStep:[KIFTestStep stepToTapViewWithAccessibilityLabel:uniqueID traits:UIAccessibilityTraitButton]];
    
    return scenario;
}

@end
