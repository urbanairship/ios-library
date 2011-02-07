/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
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

#import <objc/runtime.h>

#import "UATestCase.h"
#import "UATestGlobal.h"

@implementation UATestCase

+ (void)swizzleTestClass:(Class)klass method:(SEL)origSel withMethod:(SEL)altSel {
    Class uaTestCaseClass = [self class];
    IMP imp = class_getMethodImplementation(klass, origSel);
    IMP imp_base = class_getMethodImplementation(uaTestCaseClass, origSel);
    if (imp == imp_base) {
        // add method to the sub class
        class_addMethod(klass, origSel, imp_base,
                        method_getTypeEncoding(class_getInstanceMethod(uaTestCaseClass, origSel)));
    }
    
    NSError* err = nil;
    [klass swizzleMethod:origSel withMethod:altSel error:&err];
}

+ (void)prepareAllTestCases {
    int count = objc_getClassList(NULL, 0);
    NSMutableData *classData = [NSMutableData dataWithLength:sizeof(Class) * count];
    Class *classes = (Class*)[classData mutableBytes];
    NSAssert(classes, @"Couldn't allocate class list");
    objc_getClassList(classes, count);
    
    Class uaTestCaseClass = [self class];
    for (int i = 0; i < count; ++i) {
        Class currClass = classes[i];
        if (currClass != uaTestCaseClass && isTestFixtureOfClass(currClass, uaTestCaseClass)) {
            // mock setUp/setUpClass/tearDown/tearDownClass
            [self swizzleTestClass:currClass method:@selector(setUp) withMethod:@selector(mock_setUp)];
            [self swizzleTestClass:currClass method:@selector(setUpClass) withMethod:@selector(mock_setUpClass)];
            [self swizzleTestClass:currClass method:@selector(tearDown) withMethod:@selector(mock_tearDown)];
            [self swizzleTestClass:currClass method:@selector(tearDownClass) withMethod:@selector(mock_tearDownClass)];
        }
    }
}

- (id)init {
    UALOG(@"UATestCase init");
    if (self = [super init]) {
        testCaseMocks = [[NSMutableSet alloc] init];
        singleTestMocks = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)mock:(Class)klass method:(SEL)origSel_ withMethod:(SEL)altSel_ recorder:(NSMutableSet*)recorder {
    NSError* err = nil;
    [klass swizzleMethod:origSel_
              withMethod:altSel_ error:&err];
    [recorder addObject:[NSArray arrayWithObjects:NSStringFromClass(klass),
                         NSStringFromSelector(origSel_),
                         NSStringFromSelector(altSel_), nil]];
}

- (void)_removeAllMocks:(NSMutableSet*)recorder {
    NSError* err = nil;
    for (NSArray *sels in recorder) {
        Class klass = NSClassFromString([sels objectAtIndex:0]);
        SEL origSel_ = NSSelectorFromString([sels objectAtIndex:1]);
        SEL altSel_ = NSSelectorFromString([sels objectAtIndex:2]);
        [klass swizzleMethod:origSel_
                  withMethod:altSel_ error:&err];
    }
    [recorder removeAllObjects];
}

- (void)mock:(Class)klass method:(SEL)origSel_ withMethod:(SEL)altSel_ {
    [self mock:klass method:origSel_ withMethod:altSel_ recorder:currentMockRecorder];
}

- (void)dealloc {
    [testCaseMocks release];
    [singleTestMocks release];
    [super dealloc];
}

- (BOOL)spinRunThreadWithTimeOut:(int)seconds finishedCheckFunc:(SEL)checkFunc processingString:(NSString *)processing {
    UALOG(@"Keeping run thread alive for time: %d", seconds);
    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (![self performSelector:checkFunc] && (seconds <=0 || [giveUpDate timeIntervalSinceNow] > 0)) {
            UALOG(@"%@", processing);
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
    return ![self performSelector:checkFunc];
}

- (BOOL)spinRunThreadWithTimeOut:(int)seconds finishedFlag:(BOOL *)finished processingString:(NSString *)processing {
    UALOG(@"Keeping run thread alive for time: %d", seconds);
    NSDate* giveUpDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!(*finished) && (seconds <=0 || [giveUpDate timeIntervalSinceNow] > 0)) {
        UALOG(@"%@", processing);
        NSDate* loopIntervalDate =
        [NSDate dateWithTimeIntervalSinceNow:1];
        [[NSRunLoop currentRunLoop] runUntilDate:loopIntervalDate];
    }
    return !(*finished);
}

/*
 The mock_... methods will be mocked to run before/after the original
 setUp/setUpClass/tearDown/tearDownClass methods, we use these mocked methods to
 prepare/clean test envrionment:
 1. release the shared value in UATestGlobal
 2. init/rollback the mocked methods which are mocked while testing
 */
- (void)mock_setUp {
    UALOG(@"UATestCase mock_setUp");
    [UATestGlobal shared].value = nil;
    [singleTestMocks removeAllObjects];
    currentMockRecorder = singleTestMocks;
    [self mock_setUp];
}

- (void)mock_setUpClass {
    UALOG(@"UATestCase mock_setUpClass");
    [testCaseMocks removeAllObjects];
    currentMockRecorder = testCaseMocks;
    [self mock_setUpClass];
}

- (void)mock_tearDown {
    UALOG(@"UATestCase mock_tearDown");
    [self mock_tearDown];
    [UATestGlobal shared].value = nil;
    [self _removeAllMocks:singleTestMocks];
}

- (void)mock_tearDownClass {
    UALOG(@"UATestCase mock_tearDownClass");
    [self mock_tearDownClass];
    [self _removeAllMocks:testCaseMocks];
}

-(void)setUpClass{}
-(void)tearDownClass{}
-(void)setUp{}
-(void)tearDown{}

@end
