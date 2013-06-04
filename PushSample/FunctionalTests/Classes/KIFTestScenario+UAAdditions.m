//
//  KIFTestScenario+UAAdditions.m
//  PushSampleLib
//
//  Created by Jeff Towle on 6/1/13.
//
//

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
    //[scenario addStep:[KIFTestStep stepToReset]];
    //[scenario addStepsFromArray:[KIFTestStep stepsToGoToLoginPage]];
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

    return scenario;
}


@end
