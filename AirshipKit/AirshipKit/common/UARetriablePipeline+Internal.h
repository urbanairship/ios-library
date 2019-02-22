/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARetriable+Internal.h"
#import "UADispatcher+Internal.h"

/**
 * An interface for running retriables with optional operation dependency semantics,
 * and automatic exponential backoff. Retries will be scheduled using the dispatcher
 * to avoid blocking other operations from executing.
 */
@interface UARetriablePipeline : NSObject

/**
 * UARetriablePipeline class factory.
 */
+ (instancetype)pipeline;

/**
 * UARetriablePipeline class factory. For testing purposes.
 *
 * @param queue The NSOperation queue to use.
 * @param dispatcher The dispatcher used for rescheduling retriables.
 */
+ (instancetype)pipelineWithQueue:(NSOperationQueue *)queue dispatcher:(UADispatcher *)dispatcher;

/**
 * Adds a retriable to the queue.
 */
- (void)addRetriable:(UARetriable *)retriable;

/**
 * Adds an array of retriables to the queue, with implicit operation dependencies in
 * array order.
 */
- (void)addChainedRetriables:(NSArray<UARetriable *> *)retriables;

@end
