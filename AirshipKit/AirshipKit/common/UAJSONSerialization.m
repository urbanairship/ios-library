/* Copyright Urban Airship and Contributors */

#import "UAJSONSerialization+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAGlobal.h"
#import "UAJSONSerialization+Internal.h"

@implementation UAJSONSerialization

+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error {
    if (![NSJSONSerialization isValidJSONObject:obj]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to serialize an invalid JSON object: %@", obj];
            *error =  [NSError errorWithDomain:UAJSONSerializationErrorDomain
                                          code:UAJSONSerializationErrorCodeInvalidObject
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];

            UA_LERR(@"Attempted to serialize an invalid JSON object: %@", obj);
        }

        return nil;
    }

    return [NSJSONSerialization dataWithJSONObject:obj options:opt error:error];
}

@end
