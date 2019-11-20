/* Copyright Airship and Contributors */

#import "UAJSONValueTransformer+Internal.h"

#import "UAAirshipMessageCenterCoreImport.h"

@implementation UAJSONValueTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(NSDictionary *)value {
    return [UAJSONSerialization dataWithJSONObject:value
                                           options:NSJSONWritingPrettyPrinted
                                             error:nil];
}

- (id)reverseTransformedValue:(id)value {
    return [NSJSONSerialization JSONObjectWithData: value
                                           options: NSJSONReadingMutableContainers
                                             error: nil];
}

@end
