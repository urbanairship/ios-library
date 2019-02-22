/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageResolution+Internal.h"

#define kUAInAppMessageResolutionTypeKey @"type"
#define kUAInAppMessageResolutionButtonInfoKey @"button_info"

#define kUAInAppMessageResolutionButtonClickValue @"button_click"
#define kUAInAppMessageResolutionMessageClickValue @"message_click"
#define kUAInAppMessageResolutionUserDismissedValue @"user_dismissed"
#define kUAInAppMessageResolutionTimedOutValue @"timed_out"

#define kUAInAppMessageResolutionErrorDomain @"com.urbanairship.in_app_message_resolution"

@interface UAInAppMessageResolution()
@property (nonatomic, strong, nullable) UAInAppMessageButtonInfo *buttonInfo;
@property (nonatomic, assign) UAInAppMessageResolutionType type;
@end

@implementation UAInAppMessageResolution

- (instancetype)initWithType:(UAInAppMessageResolutionType)type
                  buttonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    self = [super init];

    if (self) {
        self.type = type;
        self.buttonInfo = buttonInfo;
    }

    return self;
}

+ (instancetype)buttonClickResolutionWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeButtonClick
                           buttonInfo:buttonInfo];
}


+ (instancetype)messageClickResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeMessageClick
                           buttonInfo:nil];
}


+ (instancetype)userDismissedResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeUserDismissed
                           buttonInfo:nil];
}

+ (instancetype)timedOutResolution {
    return [[self alloc] initWithType:UAInAppMessageResolutionTypeTimedOut
                           buttonInfo:nil];
}

+ (nullable instancetype)resolutionWithJSON:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:kUAInAppMessageResolutionErrorDomain
                                          code:UAInAppMessageResolutionErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    id typeString = json[kUAInAppMessageResolutionTypeKey];

    if (![typeString isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message resolution type must be a string. Invalid value: %@", typeString];
            *error =  [NSError errorWithDomain:kUAInAppMessageResolutionErrorDomain
                                          code:UAInAppMessageResolutionErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    UAInAppMessageResolutionType type;

    if ([typeString isEqualToString:kUAInAppMessageResolutionButtonClickValue]) {
        type = UAInAppMessageResolutionTypeButtonClick;
    } else if ([typeString isEqualToString:kUAInAppMessageResolutionMessageClickValue]) {
        type = UAInAppMessageResolutionTypeMessageClick;
    } else if ([typeString isEqualToString:kUAInAppMessageResolutionTimedOutValue]) {
        type = UAInAppMessageResolutionTypeTimedOut;
    } else if ([typeString isEqualToString:kUAInAppMessageResolutionUserDismissedValue]) {
        type = UAInAppMessageResolutionTypeUserDismissed;
    } else {
        if (error) {
            NSArray *validTypes = @[kUAInAppMessageResolutionMessageClickValue, kUAInAppMessageResolutionButtonClickValue,
                                    kUAInAppMessageResolutionTimedOutValue, kUAInAppMessageResolutionUserDismissedValue];

            NSString *msg = [NSString stringWithFormat:@"In-app message resolution type must be one of: %@. Invalid value: %@", validTypes, typeString];

            *error =  [NSError errorWithDomain:kUAInAppMessageResolutionErrorDomain
                                          code:UAInAppMessageResolutionErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    UAInAppMessageButtonInfo *buttonInfo;

    if (type == UAInAppMessageResolutionTypeButtonClick) {
        id buttonInfoJSON = json[kUAInAppMessageResolutionButtonInfoKey];
        buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:buttonInfoJSON error:error];

        if (!buttonInfo) {
            return nil;
        }
    }

    return [[self alloc] initWithType:type buttonInfo:buttonInfo];
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    if (self.type == UAInAppMessageResolutionTypeButtonClick) {
        [json setValue:kUAInAppMessageResolutionButtonClickValue forKey:kUAInAppMessageResolutionTypeKey];
    } else if (self.type == UAInAppMessageResolutionTypeMessageClick) {
        [json setValue:kUAInAppMessageResolutionMessageClickValue forKey:kUAInAppMessageResolutionTypeKey];
    } else if (self.type == UAInAppMessageResolutionTypeTimedOut) {
        [json setValue:kUAInAppMessageResolutionTimedOutValue forKey:kUAInAppMessageResolutionTypeKey];
    } else if (self.type == UAInAppMessageResolutionTypeUserDismissed) {
        [json setValue:kUAInAppMessageResolutionUserDismissedValue forKey:kUAInAppMessageResolutionTypeKey];
    }

    if (self.buttonInfo) {
        [json setValue:[self.buttonInfo toJSON] forKey:kUAInAppMessageResolutionButtonInfoKey];
    }

    return [json copy];
}

@end

