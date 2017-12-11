/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent.h"

@implementation UAInAppMessageBuilder


NSString * const UAInAppMessageErrorDomain = @"com.urbanairship.in_app_message";

@end

@implementation UAInAppMessage

// Keys via IAM v2 spec
NSString *const UAInAppMessageIDKey = @"message_id";
NSString *const UAInAppMessageDisplayTypeKey = @"display_type";
NSString *const UAInAppMessageDisplayContentKey = @"display";
NSString *const UAInAppMessageExtrasKey = @"extras";

NSString *const UAInAppMessageDisplayTypeBanner = @"banner";
NSString *const UAInAppMessageDisplayTypeFullScreen = @"full_screen";
NSString *const UAInAppMessageDisplayTypeModal = @"modal";
NSString *const UAInAppMessageDisplayTypeHTML = @"html";
NSString *const UAInAppMessageDisplayTypeCustom = @"custom";

+ (instancetype)message {
    return [[self alloc] init];
}

+ (instancetype)messageWithJSON:(NSDictionary *)json error:(NSError * _Nullable *)error {
    UAInAppMessageBuilder *builder = [[UAInAppMessageBuilder alloc] init];

    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                          code:UAInAppMessageErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    id identifier = json[UAInAppMessageIDKey];
    if (identifier && ![identifier isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Message identifier must be a string. Invalid value: %@", identifier];
            *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                          code:UAInAppMessageErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    UAInAppMessageDisplayContent *displayContent;
    id displayContentDict = json[UAInAppMessageDisplayContentKey];
    if (displayContentDict) {
        if (![displayContentDict isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Display content must be a dictionary. Invalid value: %@", json[UAInAppMessageMediaKey]];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
        
        displayContent = displayContentDict;
    }

    id displayType = json[UAInAppMessageDisplayTypeKey];
    if (displayType && [displayType isKindOfClass:[NSString class]]) {
        NSString *displayTypeStr = [displayType lowercaseString];

        if ([UAInAppMessageDisplayTypeBanner isEqualToString:displayTypeStr]) {
            displayTypeStr = UAInAppMessageDisplayTypeBanner;
            displayContent = [UAInAppMessageBannerDisplayContent bannerDisplayContentWithJSON:displayContentDict error:error];
        } else if ([UAInAppMessageDisplayTypeFullScreen isEqualToString:displayTypeStr]) {
            displayTypeStr = UAInAppMessageDisplayTypeFullScreen;
            // TODO uncomment this when modal is implemented see banner above for example
            //displayContent = [UAInAppMessageFullScreenDisplayContent fullScreenDisplayContentWithJSON:displayContentDict error:error];
        } else if ([UAInAppMessageDisplayTypeModal isEqualToString:displayTypeStr]) {
            displayTypeStr = UAInAppMessageDisplayTypeModal;
            // TODO uncomment this when modal is implemented see banner above for example
            //displayContent = [UAInAppMessageModalDisplayContent modalDisplayContentWithJSON:displayContentDict error:error];
        } else if ([UAInAppMessageDisplayTypeHTML isEqualToString:displayTypeStr]) {
            displayTypeStr = UAInAppMessageDisplayTypeHTML;
            // TODO uncomment this when modal is implemented see banner above for example
            //displayContent = [UAInAppMessageHTMLDisplayContent htmlDisplayContentWithJSON:displayContentDict error:error];
        } else if ([UAInAppMessageDisplayTypeCustom isEqualToString:displayTypeStr]) {
            displayTypeStr = UAInAppMessageDisplayTypeCustom;
            // TODO uncomment this when modal is implemented see banner above for example
            //displayContent = [UAInAppMessageCustomDisplayContent customDisplayContentWithJSON:displayContentDict error:error];
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message display type must be a string represening a valid display type. Invalid value: %@", displayTypeStr];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

        if (!displayContent) {
            return nil;
        }
    }

    id extras = json[UAInAppMessageExtrasKey];
    if (extras && ![extras isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Message extras must be a dictionary. Invalid value: %@", extras];
            *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                          code:UAInAppMessageErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    builder.json = json;
    builder.identifier = identifier;
    builder.displayType = displayType;
    builder.extras = extras;
    builder.displayContent = displayContent;

    return [[UAInAppMessage alloc] initWithBuilder:builder];
}

+ (instancetype)messageWithBuilderBlock:(void(^)(UAInAppMessageBuilder *builder))builderBlock {
    UAInAppMessageBuilder *builder = [[UAInAppMessageBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessage alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(UAInAppMessageBuilder *)builder {
    self = [super init];
    if (self) {
        self.json = builder.json;
        self.identifier = builder.identifier;
        self.displayType = builder.displayType;
        self.displayContent = builder.displayContent;
        self.extras = builder.extras;
    }

    return self;
}

- (BOOL)isEqualToInAppMessage:(UAInAppMessage *)message {
    if (![self.identifier isEqualToString:message.identifier]) {
        return NO;
    }

    if (self.displayType != message.displayType) {
        return NO;
    }

    // Do we need to check type here first? make sure
    if ([self.displayContent isEqual:message.displayContent]) {
        return NO;
    }

    if (![self.extras isEqualToDictionary:message.extras]) {
        return NO;
    }

    return YES;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessage class]]) {
        return NO;
    }

    return [self isEqualToInAppMessage:(UAInAppMessage *)object];
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.identifier hash];
    result = 31 * result + [self.displayType hash];
    result = 31 * result + [self.displayContent hash];
    result = 31 * result + [self.extras hash];

    return result;
}

//TODO implement description method

@end
