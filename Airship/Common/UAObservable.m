/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import "UAirship.h"
#import "UAObservable.h"


@implementation UAObservable

-(void)dealloc {
    [observers release];
    observers = nil;
    [observerLock release];
    observerLock = nil;
    [super dealloc];
}

-(id)init {
    @synchronized(self) {
        if(self = [super init]) {
            observers = [[NSMutableSet alloc] init];
            observerLock = [[NSLock alloc] init];
        }
    }
    return self;
}

-(void)notifyObservers:(SEL)selector {
    @synchronized(self) {
        NSSet* observer_copy = [observers copy];
         //TODO, there has got to be a better way to avoid http://paste.pocoo.org/show/lNe6xjcgRjeDYOtl2jnX/
        for (id observer in observer_copy) {
            if([observer respondsToSelector: selector]) {
                [observer performSelector: selector];
            }
        }
        [observer_copy release];
    }
}

-(void)notifyObservers:(SEL)selector withObject:(id)arg1 {
    @synchronized(self) {
        NSSet* observer_copy = [observers copy];
        for (id observer in observer_copy) {
            if([observer respondsToSelector: selector]) {
                [observer performSelector: selector withObject: arg1];
            }
        }
        [observer_copy release];
    }
}

-(void)notifyObservers:(SEL)selector withObject:(id)arg1 withObject:(id)arg2 {
    @synchronized(self) {
        NSSet* observer_copy = [observers copy];
        for (id observer in observer_copy) {
            if([observer respondsToSelector: selector]) {
                [observer performSelector: selector withObject: arg1 withObject: arg2];
            }
        }
        [observer_copy release];
    }
}


-(void)addObserver:(id)observer {
    @synchronized(self) {
        [observers addObject: observer];
    }
}

-(void)removeObserver:(id)observer {
    @synchronized(self) {
        [observers removeObject: observer];
    }
}

-(void)removeObservers {
    @synchronized(self) {
        [observers removeAllObjects];
    }
}

-(int)countObservers {
    return [observers count];
}

@end
