//
//  UATestingDelegate.m
//  PushSampleLib
//
//  Created by Jeff Towle on 6/1/13.
//
//

#import "UATestingDelegate.h"

#import "UAGlobal.h"

#import "UATestController.h"


@implementation UATestingDelegate

SINGLETON_IMPLEMENTATION(UATestingDelegate);

/* this method is called the moment the class is made known to the obj-c runtime,
 before app launch completes. */
+ (void)load {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:[UATestingDelegate shared] selector:@selector(runKIF:) name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
}

- (void)runKIF:(NSNotification *)notification {
    [[UATestController sharedInstance] startTestingWithCompletionBlock:^{
        // Exit after the tests complete so that CI knows we're done
        exit([[UATestController sharedInstance] failureCount]);
    }];
}

@end

