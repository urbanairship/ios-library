/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARetriable+Internal.h"

/**
 * An interface for running retriables with optional operation dependency semantics,
 * and automatic exponential backoff.
 */
@interface UARetriablePipeline : NSObject

/**
 * UARetriablePipeline class factory.
 */
+ (instancetype)pipeline;

/**
 * UARetriablePipeline class factory.
 *
 * @param queue The NSOperation queue to use. For testing purposes.
 */
+ (instancetype)pipelineWithQueue:(NSOperationQueue *)queue;

/**
 * Adds a retriable to the queue.
 */
- (void)addRetriable:(UARetriable *)retriable;

/**
 * Adds an array of retriables to the queue, with implicit operation dependencies in
 * array order.
 */
- (void)addChainedRetriables:(NSArray<UARetriable *> *)retriables;

/**
 * Cancels all operations.
 */
- (void)cancel;

@end
