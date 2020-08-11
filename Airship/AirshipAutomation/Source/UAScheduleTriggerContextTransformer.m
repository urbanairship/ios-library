/* Copyright Airship and Contributors */

#import "UAScheduleTriggerContextTransformer+Internal.h"
#import "UAScheduleTriggerContext+Internal.h"
#import "UAScheduleTrigger+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

@implementation UAScheduleTriggerContextTransformer

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
                                                      error:&error];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}

- (id)reverseTransformedValue:(id)value {
    NSError *error = nil;
    id result = [NSKeyedUnarchiver unarchivedObjectOfClass:[UAScheduleTriggerContext class]
                                                  fromData:value
                                                     error:&error];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}
@end
