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

/******************************************************************************
 The swizzle method is copy/modify from JRSwizzle, thanks
 Copyright (c) 2007 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
 Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 *****************************************************************************/

#import "NSObject+UATestMockable.h"

#import <objc/runtime.h>
#import "UATestGlobal.h"

#define SetNSError(ERROR_VAR, FORMAT,...)	\
if (ERROR_VAR) {	\
NSString *errStr = [@"+[NSObject(UATestMockable) swizzleMethod:withClass:method:error:]: " stringByAppendingFormat:FORMAT,##__VA_ARGS__];	\
*ERROR_VAR = [NSError errorWithDomain:@"NSCocoaErrorDomain" \
code:-1	\
userInfo:[NSDictionary dictionaryWithObject:errStr forKey:NSLocalizedDescriptionKey]]; \
NSLog(@"Swizzle error: %@", errStr); \
}

@implementation NSObject(UATestMockable)


+ (NSString *)getCallKey:(SEL)aSelector {
    return [NSString stringWithFormat:@"%@/%@",
            NSStringFromClass(self),
            NSStringFromSelector(aSelector)];
}

+ (BOOL)swizzleMethod:(SEL)origSel withMethod:(SEL)altSel error:(NSError**)error {
    return [self swizzleMethod:origSel withClass:self method:altSel error:error];
}

+ (BOOL)swizzleMethod:(SEL)origSel withClass:(Class)klass method:(SEL)altSel error:(NSError**)error {
    Method origMethod = class_getInstanceMethod(self, origSel);
	if (!origMethod) {
		SetNSError(error, @"original method %@ not found for class %@", NSStringFromSelector(origSel), NSStringFromClass([self class]));
		return NO;
	}
	
	Method altMethod = class_getInstanceMethod(klass, altSel);
	if (!altMethod) {
		SetNSError(error, @"alternate method %@ not found for class %@", NSStringFromSelector(altSel), NSStringFromClass(klass));
		return NO;
	}

	class_addMethod(self,
					altSel,
					class_getMethodImplementation(klass, altSel),
					method_getTypeEncoding(altMethod));
	
	method_exchangeImplementations(class_getInstanceMethod(self, origSel), class_getInstanceMethod(self, altSel));
	return YES;
}

+ (void)recordCallSelector:(SEL)aSelector withArgs:(NSArray *)args {
    id callArgs = args;
    if (!callArgs) {
        callArgs = [NSNull null];
    }
    NSMutableArray *_calls = (NSMutableArray *)[self getCalls:aSelector];
    if (!_calls) {
        _calls = [NSMutableArray arrayWithObjects:callArgs, nil];
        [[UATestGlobal shared].calls setObject:_calls forKey:[self getCallKey:aSelector]];
    } else {
        [_calls addObject:callArgs];
    }
}

+ (void)removeAllCalls {
    NSString *keyPre = [NSString stringWithFormat:@"%@/",
                        NSStringFromClass(self)];
    NSMutableArray *removeKeys = [[NSMutableArray alloc] init];
    for (NSString *key in [[UATestGlobal shared].calls allKeys]) {
        if ([key hasPrefix:keyPre]) {
            [removeKeys addObject:key];
        }
    }
    [[UATestGlobal shared].calls removeObjectsForKeys:removeKeys];
    [removeKeys release];
}

+ (void)removeCalls:(SEL)aSelector {
    return [[UATestGlobal shared].calls removeObjectForKey:[self getCallKey:aSelector]];
}

+ (NSArray *)getCalls:(SEL)aSelector {
    return (NSArray *)[[UATestGlobal shared].calls objectForKey:[self getCallKey:aSelector]];
}

+ (NSInteger)getCallTimes:(SEL)aSelector {
    NSArray *_calls = [self getCalls:aSelector];
    return _calls ? [_calls count] : 0;
}

+ (NSArray *)getCallArgs:(SEL)aSelector {
    NSArray *_calls = [self getCalls:aSelector];
    return _calls ? _calls : [NSArray array];
}

+ (NSArray *)getCallArgs:(SEL)aSelector atIndex:(NSInteger)index {
    NSArray *_calls = [self getCalls:aSelector];
    if (_calls && _calls.count>index) {
        return (NSArray *)[_calls objectAtIndex:index];
    }
    return nil;
}

- (void)doNothing {}
- (void)doNothing:(id)_ {}
- (BOOL)returnYES {return YES;}
- (BOOL)returnYES:(id)_ {return YES;}
- (BOOL)returnNO {return NO;}
- (BOOL)returnNO:(id)_ {return NO;}
- (id)returnNil {return nil;}
- (id)returnNil:(id)_ {return nil;}
- (id)returnGlobalValue {return [UATestGlobal shared].value;}
- (id)returnGlobalValue:(id)_ {return [UATestGlobal shared].value;}

@end
