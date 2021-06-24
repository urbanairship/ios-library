/* Copyright Airship and Contributors */

#import "NSObject+UAAdditions.h"
#import "UAGlobal.h"
#import <objc/runtime.h>

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif


@interface UAAnonymousObserver()

@property (nonatomic, strong) id object;
@property (nonatomic, strong) UAAnonymousKVOBlock block;

@end

@interface NSObject();
@property (nonatomic, strong) NSMutableSet *anonymousObservers;
@end

@implementation UAAnonymousObserver

- (void)observe:(id)obj atKeypath:(NSString *)path withBlock:(UAAnonymousKVOBlock)block {
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

@implementation NSObject(UAAdditions)

@dynamic anonymousObservers;

- (UADisposable *)observeAtKeyPath:(NSString *)keyPath withBlock:(UAAnonymousKVOBlock)block {
    UAAnonymousObserver *obs = [UAAnonymousObserver new];

    @synchronized(self) {
        if (!self.anonymousObservers) {
            self.anonymousObservers = [NSMutableSet setWithObject:obs];
        } else {
            [self.anonymousObservers addObject:obs];
        }
    }

    [obs observe:self atKeypath:keyPath withBlock:block];

    UA_WEAKIFY(self)
    return [[UADisposable alloc] init:^{
        UA_STRONGIFY(self)
        [self removeObserver:obs forKeyPath:keyPath];
        @synchronized(self) {
            [self.anonymousObservers removeObject:obs];
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
