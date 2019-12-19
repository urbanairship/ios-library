/* Copyright Airship and Contributors */

#import "UANSURLValueTransformer.h"
#import "UAGlobal.h"

@implementation UANSURLValueTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    NSError *error = nil;
    id result = [NSKeyedArchiver archivedDataWithRootObject:value
                                      requiringSecureCoding:YES
                                                      error:nil];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}

- (id)reverseTransformedValue:(id)value {
    NSError *error = nil;
    id result = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSURL class] fromData:value error:nil];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}

@end
