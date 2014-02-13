
#import <Foundation/Foundation.h>

/**
 * Convenience interface for synchronizing tests across runloop iterations with dispatch semaphores.
 */
@interface UATestSynchronizer : NSObject

#if OS_OBJECT_USE_OBJC
/**
 * The dispatch semaphore used for synchronization
 */
@property(nonatomic, strong) dispatch_semaphore_t semaphore;    // GCD objects use ARC
#else
@property(nonatomic, assign) dispatch_semaphore_t semaphore;    // GCD object don't use ARC
#endif

/**
 * How long the runloop should spin for each iteration while waiting.
 * Default is 0.1 seconds.
 */
@property(nonatomic, assign) NSTimeInterval runLoopInterval;
/**
 * How long to wait for a completion signal before timing out.
 * Default is 2 seconds.
 */
@property(nonatomic, assign) NSTimeInterval timeoutInterval;

/**
 * Spin the run loop iteratively until either a completion signal is delivered,
 * or the timeout is reached.
 */
- (void)wait;

/**
 * Delivers a completion signal on the semaphore.
 */
- (void)continue;

@end
