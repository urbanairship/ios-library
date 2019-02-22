/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>
#import "NSOperationQueue+UAAdditions.h"
#import "UADelayOperation+Internal.h"

@implementation NSOperationQueue(UAAdditions)

- (BOOL)addBackgroundOperation:(NSOperation *)operation
                         delay:(NSTimeInterval)seconds {

    NSPointerArray *operations = [NSPointerArray weakObjectsPointerArray];
    [operations addPointer:(__bridge void *)operation];

    __block UIBackgroundTaskIdentifier backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        for (id operation in operations) {
            [operation cancel];
        }

        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
            backgroundTask = UIBackgroundTaskInvalid;
        }
    }];

    if (backgroundTask == UIBackgroundTaskInvalid) {
        return NO;
    }

    void (^originalBlock)(void) = operation.completionBlock;

    operation.completionBlock = ^() {
        if (originalBlock) {
            originalBlock();
        }

        if (backgroundTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        }
    };

    if (seconds) {
        UADelayOperation *delayOperation = [UADelayOperation operationWithDelayInSeconds:seconds];
        [operations addPointer:(__bridge void *)delayOperation];
        [operation addDependency:delayOperation];
        [self addOperations:@[delayOperation, operation] waitUntilFinished:NO];
    } else {
        [self addOperation:operation];
    }

    return YES;
}




@end
