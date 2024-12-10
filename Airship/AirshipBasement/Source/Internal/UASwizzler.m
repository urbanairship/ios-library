/* Copyright Airship and Contributors */

#import "UASwizzler+Internal.h"
#import <objc/runtime.h>

@interface UASwizzlerEntry: NSObject
@property (nonatomic, assign) Class swizzledClass;
@property (nonatomic, strong) NSValue *originalMethod;
@property (nonatomic, copy) NSString *selectorString;
@end

@implementation UASwizzlerEntry

- (instancetype)initWithClass:(Class)swizzledClass
               originalMethod:(NSValue *)method
               selectorString:(NSString *)selectorString {
    self = [super init];

    if (self) {
        self.swizzledClass = swizzledClass;
        self.originalMethod = method;
        self.selectorString = selectorString;
    }

    return self;
}

- (IMP)implementation {
    IMP implementation;
    [self.originalMethod getValue:&implementation];
    return implementation;
}

@end



@interface UASwizzler()
@property (nonatomic, strong) NSMutableDictionary *entryMap;
@end

@implementation UASwizzler

- (instancetype)init {
    self = [super init];

    if (self) {
        self.entryMap = [NSMutableDictionary dictionary];
    }

    return self;
}

+ (instancetype)swizzler {
    return [[UASwizzler alloc] init];
}

- (void)swizzleInstance:(id)instance
               selector:(SEL)selector
         implementation:(IMP)implementation {

    Class class = [self classForSelector:selector target:instance];
    if (class) {
        [self swizzleClass:class
                  selector:selector
            implementation:implementation];
    }
}

- (void)swizzleInstance:(id)instance
               selector:(SEL)selector
               protocol:(Protocol *)protocol
         implementation:(IMP)implementation {
    Class class = [self classForSelector:selector target:instance];
    if (class) {
        [self swizzleClass:class
                  selector:selector
                  protocol:protocol
            implementation:implementation];
    }
}

- (void)swizzleClass:(Class)clazz
            selector:(nonnull SEL)selector
            protocol:(Protocol *)protocol
      implementation:(IMP)implementation {
    Method method = class_getInstanceMethod(clazz, selector);
    if (method) {
        IMP existing = method_setImplementation(method, implementation);
        if (implementation != existing) {
            [self storeOriginalImplementation:existing class:clazz selector:selector];
        }
    } else {
        struct objc_method_description description = protocol_getMethodDescription(protocol, selector, NO, YES);
        class_addMethod(clazz, selector, implementation, description.types);
    }
}

- (BOOL)swizzleClass:(Class)clazz
            selector:(SEL)selector
      implementation:(IMP)implementation {
    Method method = class_getInstanceMethod(clazz, selector);
    if (method) {
        IMP existing = method_setImplementation(method, implementation);
        if (implementation != existing) {
            [self storeOriginalImplementation:existing class:clazz selector:selector];
        }
        return YES;
    }
    return NO;
}

- (void)unswizzle {
    for (UASwizzlerEntry *entry in self.entryMap.allValues) {
        SEL selector = NSSelectorFromString(entry.selectorString);
        Method method = class_getInstanceMethod(entry.swizzledClass, selector);
        IMP originalImplementation = [entry implementation];
        method_setImplementation(method, originalImplementation);
    }

    [self.entryMap removeAllObjects];
}

- (void)storeOriginalImplementation:(IMP)implementation
                              class:(Class)clazz
                           selector:(SEL)selector {
    NSString *selectorString = NSStringFromSelector(selector);

    self.entryMap[selectorString] = [[UASwizzlerEntry alloc] initWithClass:clazz
                                                            originalMethod:[NSValue valueWithPointer:implementation]
                                                                  selectorString:selectorString];
}

- (IMP)originalImplementation:(SEL)selector {
    NSString *selectorString = NSStringFromSelector(selector);

    UASwizzlerEntry *entry = self.entryMap[selectorString];
    return [entry implementation];
}

- (Class)classForSelector:(SEL)selector target:(id)target {
    // If the class has the method return it
    id classTarget = [target class];
    if (class_getInstanceMethod(classTarget, selector)) {
        return classTarget;
    }

    // Fallback to forward target if we have it
    id forwardingTarget = [target forwardingTargetForSelector:selector];
    if (forwardingTarget) {
        return [forwardingTarget class];
    }

    // Neither, add method to original class
    return [target class];
}

@end
