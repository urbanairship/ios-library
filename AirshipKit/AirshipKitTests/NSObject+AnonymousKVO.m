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
#import "UAGlobal.h"
#import <objc/runtime.h>

@interface UAAnonymousObserver()

@property (nonatomic, strong) id object;
@property (nonatomic, strong) UAAnonymousKVOBlock block;

@end

@interface NSObject();
@property (nonatomic, strong) NSMutableSet *anonymousObservers;
@end

@implementation UAAnonymousObserver

- (void)observe:(id)obj atKeypath:(NSString *)path withBlock:(UAAnonymousKVOBlock)block {
    if (!block) {
        UA_LINFO(@"KVO block must be non-null");
        return;
    }
    self.object = obj;
    self.block = block;
    [obj addObserver:self forKeyPath:path options:0 context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    self.block([object valueForKey:keyPath]);
}

@end

@implementation NSObject(AnonymousKVO)

@dynamic anonymousObservers;

- (UADisposable *)observeAtKeyPath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block {

    if (!block) {
        UA_LINFO(@"KVO block must be non-null");
        return nil;
    }

    UAAnonymousObserver *obs = [UAAnonymousObserver new];

    @synchronized(self) {
        if (!self.anonymousObservers) {
            self.anonymousObservers = [NSMutableSet setWithObject:obs];
        } else {
            [self.anonymousObservers addObject:obs];
        }
    }

    [obs observe:self atKeypath:keyPath withBlock:block];

    __weak NSObject *weakSelf = self;
    return [UADisposable disposableWithBlock:^{
        NSObject *strongSelf = weakSelf;
        [strongSelf removeObserver:obs forKeyPath:keyPath];
        @synchronized(self) {
            [strongSelf.anonymousObservers removeObject:obs];
        }
    }];
}

- (void)setAnonymousObservers:(NSSet *)anonymousObservers {
    objc_setAssociatedObject(self, @"com.urbanairship.anonymousObservers", anonymousObservers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSSet *)anonymousObservers {
    return objc_getAssociatedObject(self, @"com.urbanairship.anonymousObservers");
}

@end
