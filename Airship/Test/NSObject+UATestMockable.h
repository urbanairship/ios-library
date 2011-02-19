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

/******************************************************************************
 The swizzle method is copy/modify from JRSwizzle, thanks
 Copyright (c) 2007 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
 Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 *****************************************************************************/

#import <Foundation/Foundation.h>


@interface NSObject(UATestMockable)

+ (BOOL)swizzleMethod:(SEL)origSel_ withMethod:(SEL)altSel_ error:(NSError**)error_;
+ (BOOL)swizzleMethod:(SEL)origSel_ withClass:(Class)klass method:(SEL)altSel_ error:(NSError**)error_;

+ (void)recordCallSelector:(SEL)aSelector withArgs:(NSArray *)args;
+ (void)removeAllCalls;
+ (void)removeCalls:(SEL)aSelector;
+ (NSArray *)getCalls:(SEL)aSelector;
+ (NSInteger)getCallTimes:(SEL)aSelector;
+ (NSArray *)getCallArgs:(SEL)aSelector;
+ (NSArray *)getCallArgs:(SEL)aSelector atIndex:(NSInteger)index;

@end
