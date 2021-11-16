/* Copyright Airship and Contributors */

#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageBannerDisplayContent+Internal.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageCustomDisplayContent+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"

NSUInteger const UAInAppMessageIDLimit = 100;
NSUInteger const UAInAppMessageNameLimit = 100;

@implementation UAInAppMessageBuilder
- (instancetype)init {
    self = [super init];
    if (self) {
        // Set defaults
        self.source = UAInAppMessageSourceAppDefined;
        self.displayBehavior = UAInAppMessageDisplayBehaviorDefault;
        self.isReportingEnabled = YES;
    }
    return self;
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [self init];

    if (self) {
        self.name = message.name;
        self.displayContent = message.displayContent;
        self.extras = message.extras;
        self.actions = message.actions;
        self.source = message.source;
        self.displayBehavior = message.displayBehavior;
        self.isReportingEnabled = message.isReportingEnabled;
        self.renderedLocale = message.renderedLocale;
    }

    return self;
}

+ (instancetype)builderWithMessage:(UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (BOOL)isValid {
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
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) UAInAppMessageDisplayContent *displayContent;
@property(nonatomic, strong, nullable) NSDictionary *extras;
@property(nonatomic, strong, nullable) NSDictionary *actions;
@property(nonatomic, copy) NSString *displayBehavior;
@property(nonatomic, assign) BOOL isReportingEnabled;
@end

@implementation UAInAppMessage
@synthesize source = _source;
@synthesize renderedLocale = _renderedLocale;

NSString * const UAInAppMessageErrorDomain = @"com.urbanairship.in_app_message";

// Keys via IAM v2 spec
NSString *const UAInAppMessageDisplayTypeKey = @"display_type";
NSString *const UAInAppMessageDisplayContentKey = @"display";
NSString *const UAInAppMessageExtraKey = @"extra";
NSString *const UAInAppMessageActionsKey = @"actions";
NSString *const UAInAppMessageSourceKey = @"source";
NSString *const UAInAppMessageNameKey = @"name";
NSString *const UAInAppMessageRenderedLocaleKey = @"rendered_locale";
NSString *const UAInAppMessageRenderedLocaleLanguageKey = @"language";
NSString *const UAInAppMessageRenderedLocaleCountryKey = @"country";

NSString *const UAInAppMessageDisplayBehaviorKey = @"display_behavior";
NSString *const UAInAppMessageReportingEnabledKey = @"reporting_enabled";

NSString *const UAInAppMessageDisplayTypeBannerValue = @"banner";
NSString *const UAInAppMessageDisplayTypeFullScreenValue = @"fullscreen";
NSString *const UAInAppMessageDisplayTypeModalValue = @"modal";
NSString *const UAInAppMessageDisplayTypeHTMLValue = @"html";
NSString *const UAInAppMessageDisplayTypeCustomValue = @"custom";
NSString *const UAInAppMessageDisplayTypeAirshipLayoutValue = @"layout";

NSString *const UAInAppMessageDisplayBehaviorDefault = @"default";
NSString *const UAInAppMessageDisplayBehaviorImmediate = @"immediate";

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
            } else if ([UAInAppMessageDisplayTypeAirshipLayoutValue isEqualToString:displayTypeStr]) {
                if (@available(iOS 13.0, *)) {
                    builder.displayContent = [UAInAppMessageAirshipLayoutDisplayContent displayContentWithJSON:displayContentDict error:error];
                } else {
                    if (error) {
                        NSString *msg = [NSString stringWithFormat:@"Layout type is only available on iOS 13+"];
                        *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                                      code:UAInAppMessageErrorCodeInvalidJSON
                                                  userInfo:@{NSLocalizedDescriptionKey:msg}];
                    }
                    return nil;
                }
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

    id displayBehavior = json[UAInAppMessageDisplayBehaviorKey];
    if (displayBehavior && [displayBehavior isKindOfClass:[NSString class]]) {
        displayBehavior = [displayBehavior lowercaseString];

        if ([UAInAppMessageDisplayBehaviorDefault isEqualToString:displayBehavior]) {
            builder.displayBehavior = UAInAppMessageDisplayBehaviorDefault;
        } else if ([UAInAppMessageDisplayBehaviorImmediate isEqualToString:displayBehavior]) {
            builder.displayBehavior = UAInAppMessageDisplayBehaviorImmediate;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid display behavior: %@", displayBehavior];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }

    id isReportingEnabled = json[UAInAppMessageReportingEnabledKey];
    if (isReportingEnabled) {
        if (![isReportingEnabled isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Reporting enabled flag must be a boolean stored as an NSNumber. Invalid value: %@", isReportingEnabled];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.isReportingEnabled = [isReportingEnabled boolValue];
    }

    id renderedLocale = json[UAInAppMessageRenderedLocaleKey];
    if (renderedLocale) {
        if (![renderedLocale isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Rendered locale must be a dictionary. Invalid value: %@", renderedLocale];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        id language = renderedLocale[UAInAppMessageRenderedLocaleLanguageKey];
        id country = renderedLocale[UAInAppMessageRenderedLocaleCountryKey];

        if (!language && !country) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Rendered locale must contain one of \"country\" or \"language\" fields. \
                                 Invalid value: %@", renderedLocale];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        if ((language && ![language isKindOfClass:[NSString class]]) || (country && ![country isKindOfClass:[NSString class]])) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Language and country codes must be strings. Invalid value: %@", renderedLocale];
                *error =  [NSError errorWithDomain:UAInAppMessageErrorDomain
                                              code:UAInAppMessageErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }

        builder.renderedLocale = renderedLocale;
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

- (instancetype)init {
    self = [super init];
    if (self) {
        // Set defaults
        _source = UAInAppMessageSourceAppDefined;
        _displayBehavior = UAInAppMessageDisplayBehaviorDefault;
        _isReportingEnabled = YES;
    }
    return self;
}

- (nullable instancetype)initWithBuilder:(UAInAppMessageBuilder *)builder {
    self = [self init];
    
    if (![builder isValid]) {
        UA_LERR(@"UAInAppMessage could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }
    
    if (self) {
        self.name = builder.name;
        self.displayContent = builder.displayContent;
        self.extras = builder.extras;
        self.actions = builder.actions;
        self.displayBehavior = builder.displayBehavior;
        self.isReportingEnabled = builder.isReportingEnabled;
        _source = builder.source;
        _renderedLocale = builder.renderedLocale;
    }

    return self;
}

- (UAInAppMessageSource)source {
    return _source;
}

- (NSDictionary<NSString *, NSString *> *)renderedLocale {
    return _renderedLocale;
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
        case UAInAppMessageDisplayTypeAirshipLayout:
            [data setValue:UAInAppMessageDisplayTypeAirshipLayoutValue forKey:UAInAppMessageDisplayTypeKey];
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

    if (self.displayBehavior && [self.displayBehavior isEqualToString:UAInAppMessageDisplayBehaviorImmediate]) {
        [data setValue:UAInAppMessageDisplayBehaviorImmediate forKey:UAInAppMessageDisplayBehaviorKey];
    } else {
        [data setValue:UAInAppMessageDisplayBehaviorDefault forKey:UAInAppMessageDisplayBehaviorKey];
    }

    [data setValue:@(self.isReportingEnabled) forKey:UAInAppMessageReportingEnabledKey];
    [data setValue:[self.displayContent toJSON] forKey:UAInAppMessageDisplayContentKey];
    [data setValue:self.extras forKey:UAInAppMessageExtraKey];
    [data setValue:self.actions forKey:UAInAppMessageActionsKey];
    [data setValue:self.renderedLocale forKey:UAInAppMessageRenderedLocaleKey];

    return [data copy];
}

- (BOOL)isEqualToInAppMessage:(UAInAppMessage *)message {
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

    if (self.actions != message.actions && ![self.actions isEqualToDictionary:message.actions]) {
        return NO;
    }

    if (![self.displayBehavior isEqualToString:message.displayBehavior]) {
        return NO;
    }

    if (self.isReportingEnabled != message.isReportingEnabled) {
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
    result = 31 * result + [self.name hash];
    result = 31 * result + [self.displayContent hash];
    result = 31 * result + [self.extras hash];
    result = 31 * result + [self.actions hash];
    result = 31 * result + self.source;
    result = 31 * result + [self.displayBehavior hash];
    result = 31 * result + self.isReportingEnabled;

    return result;
}

- (UAInAppMessageDisplayType)displayType {
    return self.displayContent.displayType;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessage: %@>", [self toJSON]];
}
@end
