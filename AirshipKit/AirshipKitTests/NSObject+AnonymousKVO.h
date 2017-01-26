/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "NSObject+AnonymousKVO.h"
#import <Foundation/Foundation.h>
#import "UADisposable.h"

/**
 * Typedef for blocks passing KVO values.
 */
typedef void (^UAAnonymousKVOBlock)(id value);

/**
 * Observer class facilitating block-based KVO.
 */
@interface UAAnonymousObserver : NSObject

/**
 * The object being observed.
 */
@property (nonatomic, strong, readonly) id object;
/**
 * The block to be executed when the observed object passes new values.
 */
@property (nonatomic, strong, readonly) UAAnonymousKVOBlock block;

/**
 * Observe an object for KVO changes. New values will be passed
 * directly to the provided block.
 *
 * @param object The object to observe.
 * @param keyPath The desired key path.
 * @param block A block that will be executed when the object passes new values.
 */
- (void)observe:(id)object atKeypath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block;

@end

@interface NSObject(AnonymousKVO)

/**
 * A set of anonymous observers.
 */
@property (nonatomic, strong, readonly) NSMutableSet *anonymousObservers;

/**
 * Observe the object for KVO changes. New values will be passed
 * directly to the provided block.
 *
 * @param keyPath the desired key path.
 * @param block A block that will be executed when the object passes new values.
 * @return A UADisposable used for cancellation.
 */
- (UADisposable *)observeAtKeyPath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block;

@end
