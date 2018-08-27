/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAAsyncOperation+Internal.h"
#import "UARetriable+Internal.h"
#import "UADelay+Internal.h"

/**
 * An async operation subclass that encapsulates the work performed by a retriable.
 */
@interface UARetriableOperation : UAAsyncOperation

/**
 * UARetriableOperation class factory.
 *
 * @param retriable The retriable.
 */
+ (instancetype)operationWithRetriable:(UARetriable *)retriable;

@end
