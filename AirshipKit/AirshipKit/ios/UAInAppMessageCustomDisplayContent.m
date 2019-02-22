/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageCustomDisplayContent+Internal.h"

NSString *const UAInAppMessageCustomDisplayContentKey = @"custom";
NSString *const UAInAppMessageCustomDisplayContentDomain = @"com.urbanairship.custom_display_content";

@interface UAInAppMessageCustomDisplayContent()
@property (nonatomic, copy, nonnull) NSDictionary *value;
@end

@implementation UAInAppMessageCustomDisplayContent

- (instancetype)initWithValue:(NSDictionary *)value  {
    self = [super init];

    if (self) {
        self.value = value;
    }

    return self;
}

+ (instancetype)displayContentWithValue:(NSDictionary *)value {
    return [[self alloc] initWithValue:value];
}

+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error {
    if (![json isKindOfClass:[NSDictionary class]] || !json[UAInAppMessageCustomDisplayContentKey]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageCustomDisplayContentDomain
                                          code:UAInAppMessageCustomDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    return [self displayContentWithValue:json[UAInAppMessageCustomDisplayContentKey]];
}

- (NSDictionary *)toJSON {
    return @{ UAInAppMessageCustomDisplayContentKey: self.value };
}

-(UAInAppMessageDisplayType)displayType {
    return UAInAppMessageDisplayTypeCustom;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageCustomDisplayContent class]]) {
        return NO;
    }

    UAInAppMessageCustomDisplayContent *obj = (UAInAppMessageCustomDisplayContent *)object;
    if (self.value != obj.value && ![self.value isEqual:obj.value]) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash {
    return [self.value hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageCustomDisplayContent: %@>", [self toJSON]];
}

@end
