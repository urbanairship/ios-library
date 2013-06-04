//
//  KIFTestScenario+UAAdditions.h
//  PushSampleLib
//
//  Created by Jeff Towle on 6/1/13.
//
//

#import "KIFTestScenario.h"

@interface KIFTestScenario (UAAdditions)

+ (id)scenarioToEnablePush;
+ (id)scenarioToReceiveUnicastPush;
+ (id)scenarioToReceiveBroadcastPush;
+ (id)scenarioToSetAlias;
+ (id)scenarioToSetTag;


@end
