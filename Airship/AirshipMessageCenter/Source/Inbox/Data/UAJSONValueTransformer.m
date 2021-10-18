/* Copyright Airship and Contributors */

#import "UAJSONValueTransformer+Internal.h"
#import "UAAirshipMessageCenterCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@implementation UAJSONValueTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(NSDictionary *)value {
    return [UAJSONUtils dataWithObject:value
                               options:NSJSONWritingPrettyPrinted
                                 error:nil];
}

- (id)reverseTransformedValue:(id)value {
    return [NSJSONSerialization JSONObjectWithData: value
                                           options: NSJSONReadingMutableContainers
                                             error: nil];
}

@end
