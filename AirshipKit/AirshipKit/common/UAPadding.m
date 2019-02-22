/* Copyright Urban Airship and Contributors */

#import "UAPadding.h"
#import "UAirship.h"

NSString *const UAPaddingTopKey = @"top";
NSString *const UAPaddingBottomKey = @"bottom";
NSString *const UAPaddingTrailingKey = @"trailing";
NSString *const UAPaddingLeadingKey = @"leading";

@implementation UAPadding

+ (instancetype)paddingWithTop:(nullable NSNumber *)top
                        bottom:(nullable NSNumber *)bottom
                       leading:(nullable NSNumber *)leading
                      trailing:(nullable NSNumber *)trailing {

    return [[UAPadding alloc] initWithTop:top bottom:bottom leading:leading trailing:trailing];
}

+ (instancetype)paddingWithDictionary:(nullable NSDictionary *)paddingDict {
    if (paddingDict) {
        if ([paddingDict isKindOfClass:[NSDictionary class]]) {
            NSNumber *top = [UAPadding paddingValueInDict:paddingDict forKey:UAPaddingTopKey];
            NSNumber *bottom = [UAPadding paddingValueInDict:paddingDict forKey:UAPaddingBottomKey];
            NSNumber *trailing = [UAPadding paddingValueInDict:paddingDict forKey:UAPaddingTrailingKey];
            NSNumber *leading = [UAPadding paddingValueInDict:paddingDict forKey:UAPaddingLeadingKey];

            return [UAPadding paddingWithTop:top bottom:bottom leading:leading trailing:trailing];
        }
    }

    return [UAPadding paddingWithTop:nil bottom:nil leading:nil trailing:nil];
}

+ (NSNumber *)paddingValueInDict:(NSDictionary *)paddingDict forKey:(NSString *)key {
    id padding = paddingDict[key];
    if (padding) {
        if (![padding isKindOfClass:[NSNumber class]]) {
            UA_LDEBUG(@"Padding value from a dictionary must be an NSNumber, defaulting to nil.");
            return nil;
        }

        return padding;
    }

    return nil;
}

- (instancetype)initWithTop:(nullable NSNumber *)top
                     bottom:(nullable NSNumber *)bottom
                    leading:(nullable NSNumber *)leading
                   trailing:(nullable NSNumber *)trailing {

    self = [super init];
    if (self) {
        self.top = top;
        self.bottom = bottom;
        self.trailing = trailing;
        self.leading = leading;
    }

    return self;
}

@end

