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

#import "UAActionResult+Internal.h"

@implementation UAActionResult

- (instancetype)initWithValue:(id)value
              withFetchResult:(UAActionFetchResult)fetchResult
                   withStatus:(UAActionStatus) status {

    self = [super init];
    if (self) {
        self.value = value;
        self.fetchResult = fetchResult;
        self.status = status;
    }

    return self;
}

+ (instancetype)resultWithValue:(id)value {
    return [self resultWithValue:value withFetchResult:UAActionFetchResultNoData];
}

+ (instancetype)resultWithValue:(id)value
                 withFetchResult:(UAActionFetchResult)fetchResult {
    return [[self alloc] initWithValue:value
                       withFetchResult:fetchResult
                            withStatus:UAActionStatusCompleted];
}

+ (instancetype)emptyResult {
    return [self resultWithValue:nil withFetchResult:UAActionFetchResultNoData];
}


+ (instancetype)resultWithError:(NSError *)error
                withFetchResult:(UAActionFetchResult)fetchResult {
    UAActionResult *result = [[self alloc] initWithValue:nil
                                         withFetchResult:fetchResult
                                              withStatus:UAActionStatusError];
    result.error = error;
    return result;
}

+ (instancetype)resultWithError:(NSError *)error {
    return [self resultWithError:error withFetchResult:UAActionFetchResultNoData];
}

+ (instancetype)rejectedArgumentsResult {
    return [[self alloc] initWithValue:nil
                       withFetchResult:UAActionFetchResultNoData
                            withStatus:UAActionStatusArgumentsRejected];
}

+ (instancetype)actionNotFoundResult {
    return [[self alloc] initWithValue:nil
                       withFetchResult:UAActionFetchResultNoData
                            withStatus:UAActionStatusActionNotFound];
}
@end
