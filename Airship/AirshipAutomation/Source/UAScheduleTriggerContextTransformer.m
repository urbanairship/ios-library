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

- (id)transformedValue:(UAScheduleTriggerContext *)value {
    return value == nil ? nil : [NSKeyedArchiver archivedDataWithRootObject:value];
}

- (id)reverseTransformedValue:(id)value {
    return value == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:value];
}

@end
