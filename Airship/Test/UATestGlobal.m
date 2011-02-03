/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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

#import "UATestGlobal.h"
#import "UATestCase.h"
#import "NSObject+UATestMockable.h"

@implementation UATestGlobal

@synthesize calls;
@synthesize value;

SINGLETON_IMPLEMENTATION(UATestGlobal)

- (id)init {
    if (self=[super init]) {
        calls = [[NSMutableDictionary alloc] init];
        return self;
    }
    return nil;
}

+ (void)prepareAllTestCases {
    int count = objc_getClassList(NULL, 0);
    NSMutableData *classData = [NSMutableData dataWithLength:sizeof(Class) * count];
    Class *classes = (Class*)[classData mutableBytes];
    NSAssert(classes, @"Couldn't allocate class list");
    objc_getClassList(classes, count);

    Class uaTestCaseClass = [UATestCase class];
    for (int i = 0; i < count; ++i) {
        Class currClass = classes[i];
        if (currClass != uaTestCaseClass && isTestFixtureOfClass(currClass, uaTestCaseClass)) {
            // mock setUp/setUpClass/tearDown/tearDownClass
            NSError* err = nil;
            [currClass swizzleMethod:@selector(setUp) withMethod:@selector(mock_setUp) error:&err];
            [currClass swizzleMethod:@selector(setUpClass) withMethod:@selector(mock_setUpClass) error:&err];
            [currClass swizzleMethod:@selector(tearDown) withMethod:@selector(mock_tearDown) error:&err];
            [currClass swizzleMethod:@selector(tearDownClass) withMethod:@selector(mock_tearDownClass) error:&err];
        }
    }
}

- (void)dealloc {
    [value release];
    [calls release];
    [super dealloc];
}

@end
