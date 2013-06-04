//
//  UATestController.m
//  PushSampleLib
//
//  Created by Jeff Towle on 6/1/13.
//
//

#import "UATestController.h"

#import "KIFTestScenario+UAAdditions.h"
#import "UATestPushDelegate.h"
#import "UAPush.h"


@implementation UATestController

- (void)dealloc {
    if ([UAPush shared].delegate == self.pushDelegate) {
        [UAPush shared].delegate = nil;
    }
    self.pushDelegate = nil;

    [super dealloc];
    
}

- (void)initializeScenarios {

    // replace existing push delegate with new handler that prints the alert in the cancel button

    // pull master secret from internal airship config properties
    self.pushDelegate = [[[UATestPushDelegate alloc] init] autorelease];
    [UAPush shared].delegate = self.pushDelegate;

    [self addScenario:[KIFTestScenario scenarioToEnablePush]];
    [self addScenario:[KIFTestScenario scenarioToReceiveUnicastPush]];
    [self addScenario:[KIFTestScenario scenarioToReceiveBroadcastPush]];
    [self addScenario:[KIFTestScenario scenarioToSetAlias]];
    [self addScenario:[KIFTestScenario scenarioToSetTag]];

    // moar

}

@end
