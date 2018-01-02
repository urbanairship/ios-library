/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAGlobal.h"

@implementation UAInAppMessageBuilder

- (BOOL)isValid {
    if (!self.identifier) {
        UA_LERR(@"Messages require an ID.");
        return NO;
    }

    if (!self.displayContent) {
        UA_LERR(@"Messages require display content.");
        return NO;
    }

    return YES;
}
@end

@interface UAInAppMessage()
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, strong) UAInAppMessageDisplayContent *displayContent;
@property(nonatomic, copy, nullable) NSDictionary *extras;
@property(nonatomic, strong, nullable) UAInAppMessageAudience *audience;
@end

@implementation UAInAppMessage

NSString * const UAInAppMessageErrorDomain = @"com.urbanairship.in_app_message";

// Keys via IAM v2 spec
NSString *const UAInAppMessageIDKey = @"message_id";
NSString *const UAInAppMessageDisplayTypeKey = @"display_type";
NSString *const UAInAppMessageDisplayContentKey = @"display";
NSString *const UAInAppMessageExtrasKey = @"extras";
NSString *const UAInAppMessageAudienceKey = @"audience";

NSString *const UAInAppMessageDisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageDisplayTypeFullScreenValue = @"fullscreen";
NSString *const UAInAppMessageDisplayTypeModalValue = @"modal";
NSString *const UAInAppMessageDisplayTypeHTMLValue = @"html";
NSString *const UAInAppMessageDisplayTypeCustomValue = @"custom";

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
    if (identifier) {
        if (![identifier isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message identifier must be a string. Invalid value: %@", identifier];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.identifier = identifier;
    }

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
        
        id displayTypeStr = json[UAInAppMessageDisplayTypeKey];
        if (displayTypeStr && [displayTypeStr isKindOfClass:[NSString class]]) {
            displayTypeStr = [displayTypeStr lowercaseString];
            
            if ([UAInAppMessageDisplayTypeBannerValue isEqualToString:displayTypeStr]) {
                builder.displayContent = [UAInAppMessageBannerDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeFullScreenValue isEqualToString:displayTypeStr]) {
            	builder.displayContent = [UAInAppMessageFullScreenDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeModalValue isEqualToString:displayTypeStr]) {
                // TODO uncomment this when modal is implemented see banner above for example
                //builder.displayContent = [UAInAppMessageModalDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeHTMLValue isEqualToString:displayTypeStr]) {
                // TODO uncomment this when modal is implemented see banner above for example
                //builder.displayContent = [UAInAppMessageHTMLDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeCustomValue isEqualToString:displayTypeStr]) {
                // TODO uncomment this when modal is implemented see banner above for example
                //builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else {
                if (error) {
                    NSString *msg = [NSString stringWithFormat:@"Message display type must be a string represening a valid display type. Invalid value: %@", displayTypeStr];
                    *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                                  code:UAInAppMessageErrorCodeInvalidJSON
                                              userInfo:@{NSLocalizedDescriptionKey:msg}];
                }
                return nil;
            }
            
            if (!builder.displayContent) {
                return nil;
            }
        }
    }
    
    id extras = json[UAInAppMessageExtrasKey];
    if (extras) {
        if (![extras isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message extras must be a dictionary. Invalid value: %@", extras];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.extras = extras;
    }
    
    id audienceDict = json[UAInAppMessageAudienceKey];
    if (audienceDict) {
        if (![audienceDict isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Display content must be a dictionary. Invalid value: %@", json[UAInAppMessageAudienceKey]];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        builder.audience = [UAInAppMessageAudience audienceWithJSON:audienceDict error:error];
    }

    if (![builder isValid]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid message JSON: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                          code:UAInAppMessageErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }
    
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
    
    if (![builder isValid]) {
        UA_LDEBUG(@"UAInAppMessage could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }
    
    if (self) {
        self.identifier = builder.identifier;
        self.displayContent = builder.displayContent;
        self.extras = builder.extras;
        self.audience = builder.audience;
    }

    return self;
}

#pragma mark - Validation

- (NSDictionary *)toJSON {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    [data setValue:self.identifier forKey:UAInAppMessageIDKey];
    switch (self.displayType) {
        case UAInAppMessageDisplayTypeBanner:
            [data setValue:UAInAppMessageDisplayTypeBannerValue forKey:UAInAppMessageDisplayTypeKey];
            break;
        case UAInAppMessageDisplayTypeFullScreen:
            [data setValue:UAInAppMessageDisplayTypeFullScreenValue forKey:UAInAppMessageDisplayTypeKey];
            break;
        case UAInAppMessageDisplayTypeModal:
            [data setValue:UAInAppMessageDisplayTypeModalValue forKey:UAInAppMessageDisplayTypeKey];
            break;
        case UAInAppMessageDisplayTypeHTML:
            [data setValue:UAInAppMessageDisplayTypeHTMLValue forKey:UAInAppMessageDisplayTypeKey];
            break;
        case UAInAppMessageDisplayTypeCustom:
            [data setValue:UAInAppMessageDisplayTypeCustomValue forKey:UAInAppMessageDisplayTypeKey];
            break;
    }

    [data setValue:[self.displayContent toJSON] forKey:UAInAppMessageDisplayContentKey];
    [data setValue:[self.audience toJSON] forKey:UAInAppMessageAudienceKey];
    [data setValue:self.extras forKey:UAInAppMessageExtrasKey];

    return [data copy];
}

- (BOOL)isEqualToInAppMessage:(UAInAppMessage *)message {
    if (![self.identifier isEqualToString:message.identifier]) {
        return NO;
    }

    // Do we need to check type here first? make sure
    if (![self.displayContent isEqual:message.displayContent]) {
        return NO;
    }

    if (self.extras != message.extras && ![self.extras isEqualToDictionary:message.extras]) {
        return NO;
    }

    if (![self.audience isEqual:message.audience]) {
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
    result = 31 * result + [self.displayContent hash];
    result = 31 * result + [self.extras hash];
    result = 31 * result + [self.audience hash];

    return result;
}

- (UAInAppMessageDisplayType)displayType {
    return self.displayContent.displayType;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessage: %@>", [self toJSON]];
}
@end
