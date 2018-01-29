/* Copyright 2018 Urban Airship and Contributors */

#import "UABaseTest.h"
#import "UAirship+Internal.h"

@interface UATestNotificationObserver : NSObject

@property(nonatomic, copy) void (^block)(NSNotification *);

- (instancetype)initWithBlock:(void (^)(NSNotification *))block name:(NSNotificationName)name sender:(id)target;

@end

@implementation UATestNotificationObserver

- (instancetype)initWithBlock:(void (^)(NSNotification *))block name:(NSNotificationName)name sender:(id)sender {
    self = [super init];
    if (self) {
        self.block = block;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification:) name:name object:sender];
    }
    
    return self;
}

- (void)handleNotification:(NSNotification *)notification {
    self.block(notification);
}

@end

@interface UABaseTest()
@property (nonatomic, strong) NSPointerArray *mocks;
@property (nonatomic, strong) NSMutableArray *disposables;
@end

@implementation UABaseTest

- (void)tearDown {
    for (id disposable in self.disposables) {
        [disposable dispose];
    }
    for (id mock in self.mocks) {
        [mock stopMocking];
    }
    self.mocks = nil;
    [UAirship land];
    [super tearDown];
}

- (id)mockForProtocol:(Protocol *)protocol {
    id mock = OCMProtocolMock(protocol);
    [self addMock:mock];
    return mock;
}

- (id)partialMockForObject:(NSObject *)object {
    id mock = OCMPartialMock(object);
    [self addMock:mock];
    return mock;
}

- (id)strictMockForClass:(Class)aClass {
    id mock = OCMStrictClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (id)mockForClass:(Class)aClass {
    id mock = OCMClassMock(aClass);
    [self addMock:mock];
    return mock;
}

- (void)addMock:(id)mock {
    if (!self.mocks) {
        self.mocks = [NSPointerArray weakObjectsPointerArray];
    }
    [self.mocks addPointer:(__bridge void *)mock];
}

- (UADisposable *)startNSNotificationCenterObservingWithBlock:(void (^)(NSNotification *))block notificationName:(NSNotificationName)notificationName sender:(id)sender {
    UATestNotificationObserver *notificationObserver = [[UATestNotificationObserver alloc] initWithBlock:block name:notificationName sender:sender];
    UADisposable *observer = [UADisposable disposableWithBlock:^{
        [[NSNotificationCenter defaultCenter] removeObserver:notificationObserver];
    }];
    [self addDisposable:observer];
    return observer;
}

- (void)addDisposable:(id)disposable {
    if (!self.disposables) {
        self.disposables = [NSMutableArray array];
    }
    [self.disposables addObject:disposable];
}
@end
