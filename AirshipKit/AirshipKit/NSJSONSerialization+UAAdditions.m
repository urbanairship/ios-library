/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "NSJSONSerialization+UAAdditions.h"
#import "UAGlobal.h"

@implementation NSJSONSerialization (UAAdditions)

NSString * const UAJSONSerializationErrorDomain = @"com.urbanairship.json_serialization";

+ (NSString *)stringWithObject:(id)jsonObject {
    return [NSJSONSerialization stringWithObject:jsonObject options:0 acceptingFragments:NO error:nil];
}

+ (NSString *)stringWithObject:(id)jsonObject error:(NSError **)error {
    return [NSJSONSerialization stringWithObject:jsonObject options:0 acceptingFragments:NO error:error];
}

+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt {
    return [NSJSONSerialization stringWithObject:jsonObject options:opt acceptingFragments:NO error:nil];
}

+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt error:(NSError **)error {
    return [NSJSONSerialization stringWithObject:jsonObject options:opt acceptingFragments:NO error:error];
}

+ (NSString *)stringWithObject:(id)jsonObject acceptingFragments:(BOOL)acceptingFragments {
    return [NSJSONSerialization stringWithObject:jsonObject options:0 acceptingFragments:acceptingFragments error:nil];
}

+ (NSString *)stringWithObject:(id)jsonObject acceptingFragments:(BOOL)acceptingFragments error:(NSError **)error {
    return [NSJSONSerialization stringWithObject:jsonObject options:0 acceptingFragments:acceptingFragments error:error];
}

+ (NSString *)stringWithObject:(id)jsonObject
                       options:(NSJSONWritingOptions)opt
            acceptingFragments:(BOOL)acceptingFragments
                         error:(NSError **)error {
    if (!jsonObject) {
        return nil;
        
    }

    if (!acceptingFragments ||
        ([jsonObject isKindOfClass:[NSArray class]] || [jsonObject isKindOfClass:[NSDictionary class]])) {
        if (![NSJSONSerialization isValidJSONObject:jsonObject]) {
            UA_LWARN(@"Attempting to JSON-serialize a non-foundation object. Returning nil.");
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to serialize invalid object: %@", jsonObject];
                NSDictionary *info = @{NSLocalizedDescriptionKey:msg};
                *error =  [NSError errorWithDomain:UAJSONSerializationErrorDomain
                                              code:UAJSONSerializationErrorCodeInvalidObject
                                          userInfo:info];
            }
            return nil;
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                       options:opt
                                                         error:error];

        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else {
        //this is a dirty hack but it works well. while NSJSONSerialization doesn't allow writing of
        //fragments, if we serialize the value in an array without pretty printing, and remove the
        //surrounding bracket characters, we get the equivalent result.
        NSString *arrayString = [self stringWithObject:@[jsonObject] options:0 acceptingFragments:NO error:error];
        return [arrayString substringWithRange:NSMakeRange(1, arrayString.length-2)];
    }
}

+ (id)objectWithString:(NSString *)jsonString {
    return [self objectWithString:jsonString options:NSJSONReadingMutableContainers];
}

+ (id)objectWithString:(NSString *)jsonString options:(NSJSONReadingOptions)opt {
    return [self objectWithString:jsonString options:opt error:nil];
}

+ (id)objectWithString:(NSString *)jsonString options:(NSJSONReadingOptions)opt error:(NSError **)error {
    if (!jsonString) {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData: [jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                           options: opt
                                             error: error];
}


@end
