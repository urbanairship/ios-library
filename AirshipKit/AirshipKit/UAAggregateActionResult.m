/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import "UAAggregateActionResult.h"
#import "UAActionResult+Internal.h"

@implementation UAAggregateActionResult

- (instancetype)init {

    self = [super init];
    if (self) {
        self.value = [NSMutableDictionary dictionary];
        self.fetchResult = UAActionFetchResultNoData;
    }

    return self;
}

- (void)addResult:(UAActionResult *)result forAction:(NSString*)actionName {
    @synchronized(self) {
        NSMutableDictionary *resultDictionary = (NSMutableDictionary *)self.value;
        [resultDictionary setValue:result forKey:actionName];
        [self mergeFetchResult:result.fetchResult];
    }
}

- (UAActionResult *)resultForAction:(NSString*)actionName {
    NSMutableDictionary *resultDictionary = (NSMutableDictionary *)self.value;
    return [resultDictionary valueForKey:actionName];
}

- (void)mergeFetchResult:(UAActionFetchResult)result {
    if (self.fetchResult == UAActionFetchResultNewData || result == UAActionFetchResultNewData) {
        self.fetchResult = UAActionFetchResultNewData;
    } else if (self.fetchResult == UAActionFetchResultFailed || result == UAActionFetchResultFailed) {
        self.fetchResult = UAActionFetchResultFailed;
    }
}

@end
