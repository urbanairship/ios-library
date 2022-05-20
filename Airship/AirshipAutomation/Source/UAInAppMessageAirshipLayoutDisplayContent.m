/* Copyright Airship and Contributors */

#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

static NSString * const LayoutKey = @"layout";

API_AVAILABLE(ios(13.0))
@interface UAInAppMessageAirshipLayoutDisplayContent()
@property (nonatomic, copy, nonnull) NSDictionary *value;
@end

@implementation UAInAppMessageAirshipLayoutDisplayContent

- (instancetype)initWithJSON:(NSDictionary *)value  {
    self = [super init];

    if (self) {
        self.value = value;
    }

    return self;
}

+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error {
    
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [UAirshipErrors parseError:@"invalid json"];
        }
        return nil;
    }
    
    id layout = json[LayoutKey];
    if (!layout || ![layout isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [UAirshipErrors parseError:@"invalid json"];
        }
        return nil;
    }
    
    NSError *thomasError;
    [UAThomas validateWithJson:layout error:&thomasError];
    
    if (thomasError != nil) {
        UA_LDEBUG(@"Invalid Airship layout %@", thomasError);
        if (error) {
            *error = thomasError;
        }
        
        return nil;
    } else {
        return [[self alloc] initWithJSON:json];
    }
}

- (NSDictionary *)toJSON {
    return self.value;
}

- (NSDictionary *)layout {
    return self.value[LayoutKey];
}

-(UAInAppMessageDisplayType)displayType {
    return UAInAppMessageDisplayTypeAirshipLayout;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageAirshipLayoutDisplayContent class]]) {
        return NO;
    }

    UAInAppMessageAirshipLayoutDisplayContent *obj = (UAInAppMessageAirshipLayoutDisplayContent *)object;
    if (self.value != obj.value && ![self.value isEqual:obj.value]) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash {
    return [self.value hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageAirshipLayoutDisplayContent: %@>", [self toJSON]];
}

@end
