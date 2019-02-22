/* Copyright Urban Airship and Contributors */

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageAudience+Internal.h"
#import "UAGlobal.h"

NSUInteger const UAInAppMessageIDLimit = 100;
NSUInteger const UAInAppMessageNameLimit = 100;


@implementation UAInAppMessageBuilder

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.identifier = message.identifier;
        self.name = message.name;
        self.displayContent = message.displayContent;
        self.extras = message.extras;
        self.actions = message.actions;
        self.audience = message.audience;
        self.source = message.source;
        self.campaigns = message.campaigns;
    }

    return self;
}

+ (instancetype)builderWithMessage:(UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (BOOL)isValid {
    if (!self.identifier.length || self.identifier.length > UAInAppMessageIDLimit) {
        UA_LERR(@"In-app message requires an identifier between [1, 100] characters");
        return NO;
    }

    if (self.name && (self.name.length < 1 || self.name.length > UAInAppMessageNameLimit)) {
        UA_LERR(@"If provided, in-app message name must be between [1, 100] characters");
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
@property(nonatomic, strong) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) UAInAppMessageDisplayContent *displayContent;
@property(nonatomic, strong, nullable) NSDictionary *extras;
@property(nonatomic, strong, nullable) UAInAppMessageAudience *audience;
@property(nonatomic, strong, nullable) NSDictionary *actions;
@end

@implementation UAInAppMessage
@synthesize campaigns = _campaigns;
@synthesize source = _source;

NSString * const UAInAppMessageErrorDomain = @"com.urbanairship.in_app_message";

// Keys via IAM v2 spec
NSString *const UAInAppMessageIDKey = @"message_id";
NSString *const UAInAppMessageDisplayTypeKey = @"display_type";
NSString *const UAInAppMessageDisplayContentKey = @"display";
NSString *const UAInAppMessageExtraKey = @"extra";
NSString *const UAInAppMessageAudienceKey = @"audience";
NSString *const UAInAppMessageActionsKey = @"actions";
NSString *const UAInAppMessageCampaignsKey = @"campaigns";
NSString *const UAInAppMessageSourceKey = @"source";
NSString *const UAInAppMessageNameKey = @"name";

NSString *const UAInAppMessageDisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageDisplayTypeFullScreenValue = @"fullscreen";
NSString *const UAInAppMessageDisplayTypeModalValue = @"modal";
NSString *const UAInAppMessageDisplayTypeHTMLValue = @"html";
NSString *const UAInAppMessageDisplayTypeCustomValue = @"custom";

NSString *const UAInAppMessageSourceAppDefinedValue = @"app-defined";
NSString *const UAInAppMessageSourceRemoteDataValue = @"remote-data";
NSString *const UAInAppMessageSourceLegacyPushValue = @"legacy-push";


+ (instancetype)messageWithJSON:(NSDictionary *)json error:(NSError * _Nullable *)error {
    return [UAInAppMessage messageWithJSON:json defaultSource:UAInAppMessageSourceAppDefined error:error];
}

+ (instancetype)messageWithJSON:(NSDictionary *)json defaultSource:(UAInAppMessageSource)defaultSource error:(NSError * _Nullable *)error {
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

    id name = json[UAInAppMessageNameKey];
    if (name) {
        if (![name isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message name must be a string. Invalid value: %@", name];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.name = name;
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
                builder.displayContent = [UAInAppMessageModalDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeHTMLValue isEqualToString:displayTypeStr]) {
                builder.displayContent = [UAInAppMessageHTMLDisplayContent displayContentWithJSON:displayContentDict error:error];
            } else if ([UAInAppMessageDisplayTypeCustomValue isEqualToString:displayTypeStr]) {
                builder.displayContent = [UAInAppMessageCustomDisplayContent displayContentWithJSON:displayContentDict error:error];
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
                UA_LERR(@"Unable to create message, missing display content");
                return nil;
            }
        }
    }
    
    id extras = json[UAInAppMessageExtraKey];
    if (extras) {
        if (![extras isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message extra must be a dictionary. Invalid value: %@", extras];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.extras = extras;
    }

    id actions = json[UAInAppMessageActionsKey];
    if (actions) {
        if (![actions isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message actions must be a dictionary. Invalid value: %@", actions];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        builder.actions = actions;
    }

    id campaigns = json[UAInAppMessageCampaignsKey];
    if (campaigns) {
        if (![campaigns isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Message campagins must be a dictionary. Invalid value: %@", campaigns];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        builder.campaigns = campaigns;
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

    id sourceStr = json[UAInAppMessageSourceKey];
    if (sourceStr && [sourceStr isKindOfClass:[NSString class]]) {
        sourceStr = [sourceStr lowercaseString];

        if ([UAInAppMessageSourceAppDefinedValue isEqualToString:sourceStr]) {
            builder.source = UAInAppMessageSourceAppDefined;
        } else if ([UAInAppMessageSourceRemoteDataValue isEqualToString:sourceStr]) {
            builder.source = UAInAppMessageSourceRemoteData;
        } else if ([UAInAppMessageSourceLegacyPushValue isEqualToString:sourceStr]) {
            builder.source = UAInAppMessageSourceLegacyPush;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid source: %@", sourceStr];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    } else {
        builder.source = defaultSource;
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

+ (nullable instancetype)messageWithBuilderBlock:(void(^)(UAInAppMessageBuilder *builder))builderBlock {
    UAInAppMessageBuilder *builder = [[UAInAppMessageBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessage alloc] initWithBuilder:builder];
}

- (nullable instancetype)initWithBuilder:(UAInAppMessageBuilder *)builder {
    self = [super init];
    
    if (![builder isValid]) {
        UA_LERR(@"UAInAppMessage could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }
    
    if (self) {
        self.identifier = builder.identifier;
        self.name = builder.name;
        self.displayContent = builder.displayContent;
        self.extras = builder.extras;
        self.audience = builder.audience;
        self.actions = builder.actions;
        _campaigns = builder.campaigns;
        _source = builder.source;
    }

    return self;
}

- (UAInAppMessageSource)source {
    return _source;
}

- (NSDictionary *)campaigns {
    return _campaigns;
}

- (nullable UAInAppMessage *)extend:(void(^)(UAInAppMessageBuilder *builder))builderBlock {
    if (builderBlock) {
        UAInAppMessageBuilder *builder = [UAInAppMessageBuilder builderWithMessage:self];
        builderBlock(builder);
        return [[UAInAppMessage alloc] initWithBuilder:builder];
    }

    UA_LDEBUG(@"Extended %@ with nil builderBlock. Returning self.", self);
    return self;
}

#pragma mark - Validation

- (NSDictionary *)toJSON {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    [data setValue:self.identifier forKey:UAInAppMessageIDKey];
    [data setValue:self.name forKey: UAInAppMessageNameKey];
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

    switch (self.source) {
        case UAInAppMessageSourceRemoteData:
            [data setValue:UAInAppMessageSourceRemoteDataValue forKey:UAInAppMessageSourceKey];
            break;

        case UAInAppMessageSourceLegacyPush:
            [data setValue:UAInAppMessageSourceLegacyPushValue forKey:UAInAppMessageSourceKey];
            break;

        case UAInAppMessageSourceAppDefined:
            [data setValue:UAInAppMessageSourceAppDefinedValue forKey:UAInAppMessageSourceKey];
            break;
    }

    [data setValue:[self.displayContent toJSON] forKey:UAInAppMessageDisplayContentKey];
    [data setValue:[self.audience toJSON] forKey:UAInAppMessageAudienceKey];
    [data setValue:self.extras forKey:UAInAppMessageExtraKey];
    [data setValue:self.actions forKey:UAInAppMessageActionsKey];
    [data setValue:self.campaigns forKey:UAInAppMessageCampaignsKey];

    return [data copy];
}

- (BOOL)isEqualToInAppMessage:(UAInAppMessage *)message {
    if (![self.identifier isEqualToString:message.identifier]) {
        return NO;
    }

    if (self.name != message.name && ![self.name isEqualToString:message.name]) {
        return NO;
    }
    
    // Do we need to check type here first? make sure
    if (![self.displayContent isEqual:message.displayContent]) {
        return NO;
    }

    if (self.extras != message.extras && ![self.extras isEqualToDictionary:message.extras]) {
        return NO;
    }

    if (self.audience != message.audience && ![self.audience isEqual:message.audience]) {
        return NO;
    }

    if (self.actions != message.actions && ![self.actions isEqualToDictionary:message.actions]) {
        return NO;
    }

    if (self.campaigns != message.campaigns && ![self.campaigns isEqualToDictionary:message.campaigns]) {
        return NO;
    }

    if (self.source != message.source) {
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
    result = 31 * result + [self.name hash];
    result = 31 * result + [self.displayContent hash];
    result = 31 * result + [self.extras hash];
    result = 31 * result + [self.audience hash];
    result = 31 * result + [self.actions hash];
    result = 31 * result + [self.campaigns hash];
    result = 31 * result + self.source;

    return result;
}

- (UAInAppMessageDisplayType)displayType {
    return self.displayContent.displayType;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessage: %@>", [self toJSON]];
}
@end
