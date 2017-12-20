/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

// JSON keys
NSString *const UAInAppMessageFullScreenActionsKey = @"actions";
NSString *const UAInAppMessageFullScreenDisplayContentDomain = @"com.urbanairship.full_screen_display_content";

NSString *const UAInAppMessageFullScreenContentLayoutHeaderMediaBodyValue = @"header_media_body";
NSString *const UAInAppMessageFullScreenContentLayoutMediaHeaderBodyValue = @"media_header_body";
NSString *const UAInAppMessageFullScreenContentLayoutHeaderBodyMediaValue = @"header_body_media";

// Constants
NSUInteger const UAInAppMessageFullScreenMaxButtons = 5;

@implementation UAInAppMessageFullScreenDisplayContentBuilder

// set default values for properties
- (instancetype)init {
    if (self = [super init]) {
        self.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        self.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        self.backgroundColor = [UIColor whiteColor];
        self.dismissButtonColor = [UIColor blackColor];
    }
    return self;
}

@end

@implementation UAInAppMessageFullScreenDisplayContent

+ (instancetype)fullScreenDisplayContentWithBuilderBlock:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock {
    UAInAppMessageFullScreenDisplayContentBuilder *builder = [[UAInAppMessageFullScreenDisplayContentBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageFullScreenDisplayContent alloc] initWithBuilder:builder];
}

+ (instancetype)fullScreenDisplayContentWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageFullScreenDisplayContentBuilder *builder = [[UAInAppMessageFullScreenDisplayContentBuilder alloc] init];

    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }
    
    if (json[UAInAppMessageHeadingKey]) {
        if (![json[UAInAppMessageHeadingKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];
        if (!builder.heading) {
            return nil;
        }
    }
    
    if (json[UAInAppMessageBodyKey]) {
        if (![json[UAInAppMessageBodyKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];
        if (!builder.body) {
            return nil;
        }
    }
    
    if (json[UAInAppMessageMediaKey]) {
        if (![json[UAInAppMessageMediaKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.media = [UAInAppMessageMediaInfo mediaInfoWithJSON:json[UAInAppMessageMediaKey] error:error];
        if (!builder.media) {
            return nil;
        }
    }
    
    NSMutableArray<UAInAppMessageButtonInfo *> *buttons = [NSMutableArray array];
    id buttonsJSONArray = json[UAInAppMessageButtonsKey];
    if (buttonsJSONArray) {
        if (![buttonsJSONArray isKindOfClass:[NSArray class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Buttons must contain an array of buttons. Invalid value %@", buttonsJSONArray];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        for (id buttonJSON in buttonsJSONArray) {
            UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:buttonJSON error:error];
            
            if (!buttonInfo) {
                return nil;
            }
            
            [buttons addObject:buttonInfo];
        }
        
        if (!buttons.count) {
            if (error) {
                NSString *msg = @"Buttons must contain at least 1 button.";
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        builder.buttons = [NSArray arrayWithArray:buttons];
    }
    
    id buttonLayoutValue = json[UAInAppMessageButtonLayoutKey];
    if (buttonLayoutValue) {
        if (![buttonLayoutValue isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Button layout must be a string. Invalid value: %@", buttonLayoutValue];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        if ([UAInAppMessageButtonLayoutJoinedValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeJoined;
        } else if ([UAInAppMessageButtonLayoutSeparateValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        } else if ([UAInAppMessageButtonLayoutStackedValue isEqualToString:buttonLayoutValue]) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app button layout type: %@", buttonLayoutValue];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }
    
    id layoutContents = json[UAInAppMessageContentLayoutKey];
    if (layoutContents) {
        if (![layoutContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Content layout must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        layoutContents = [layoutContents lowercaseString];
        
        if ([UAInAppMessageFullScreenContentLayoutMediaHeaderBodyValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageFullScreenContentLayoutMediaHeaderBody;
        } else if ([UAInAppMessageFullScreenContentLayoutHeaderMediaBodyValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        } else if ([UAInAppMessageFullScreenContentLayoutHeaderBodyMediaValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderBodyMedia;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message content layout: %@", layoutContents];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }
    
    id backgroundColor = json[UAInAppMessageBackgroundColorKey];
    if (backgroundColor) {
        if (![backgroundColor isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Background color must be a string. Invalid value: %@", backgroundColor];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.backgroundColor = [UAColorUtils colorWithHexString:backgroundColor];
    }
    
    id dismissButtonColor = json[UAInAppMessageDismissButtonColorKey];
    if (dismissButtonColor) {
        if (![dismissButtonColor isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Dismiss button color must be a string. Invalid value: %@", dismissButtonColor];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.dismissButtonColor = [UAColorUtils colorWithHexString:dismissButtonColor];
    }
    
    if (json[UAInAppMessageFooterKey]) {
        if (![json[UAInAppMessageFooterKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.footer = [UAInAppMessageButtonInfo buttonInfoWithJSON:json[UAInAppMessageFooterKey] error:error];
    }
    
    return [[UAInAppMessageFullScreenDisplayContent alloc] initWithBuilder:builder];
}

- (instancetype)initWithBuilder:(UAInAppMessageFullScreenDisplayContentBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageFullScreenDisplayContent validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageFullScreenDisplayContent could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.footer = builder.footer;
        self.buttons = builder.buttons;
        if (self.buttons.count > 2) {
            self.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
        }

        self.contentLayout = builder.contentLayout;
        self.backgroundColor = builder.backgroundColor;
        self.dismissButtonColor = builder.dismissButtonColor;
    }

    return self;
}

- (NSDictionary *)toJsonValue {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    if (self.heading) {
        json[UAInAppMessageHeadingKey] = [UAInAppMessageTextInfo JSONWithTextInfo:self.heading];
    }
    if (self.body) {
        json[UAInAppMessageBodyKey] = [UAInAppMessageTextInfo JSONWithTextInfo:self.body];
    }
    if (self.media) {
        json[UAInAppMessageMediaKey] = [UAInAppMessageMediaInfo JSONWithMediaInfo:self.media];
    }

    NSMutableArray *buttonsJSONs = [NSMutableArray array];
    for (UAInAppMessageButtonInfo *buttonInfo in self.buttons) {
        [buttonsJSONs addObject:[UAInAppMessageButtonInfo JSONWithButtonInfo:buttonInfo]];
    }
    if (buttonsJSONs.count) {
        json[UAInAppMessageButtonsKey] = buttonsJSONs;
    }

    json[UAInAppMessageFooterKey] = [UAInAppMessageButtonInfo JSONWithButtonInfo:self.footer];

    switch (self.buttonLayout) {
        case UAInAppMessageButtonLayoutTypeStacked:
            json[UAInAppMessageButtonLayoutKey] = UAInAppMessageButtonLayoutStackedValue;
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            json[UAInAppMessageButtonLayoutKey] = UAInAppMessageButtonLayoutSeparateValue;
            break;
        case UAInAppMessageButtonLayoutTypeJoined:
            json[UAInAppMessageButtonLayoutKey] = UAInAppMessageButtonLayoutJoinedValue;
            break;
    }
    
    switch (self.contentLayout) {
        case UAInAppMessageFullScreenContentLayoutHeaderMediaBody:
            json[UAInAppMessageContentLayoutKey] = UAInAppMessageFullScreenContentLayoutHeaderMediaBodyValue;
            break;
        case UAInAppMessageFullScreenContentLayoutMediaHeaderBody:
            json[UAInAppMessageContentLayoutKey] = UAInAppMessageFullScreenContentLayoutMediaHeaderBodyValue;
            break;
        case UAInAppMessageFullScreenContentLayoutHeaderBodyMedia:
            json[UAInAppMessageContentLayoutKey] = UAInAppMessageFullScreenContentLayoutHeaderBodyMediaValue;
            break;
    }
    
    json[UAInAppMessageBackgroundColorKey] = [UAColorUtils hexStringWithColor:self.backgroundColor];
    json[UAInAppMessageDismissButtonColorKey] = [UAColorUtils hexStringWithColor:self.dismissButtonColor];

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

// Validates builder contents for the FullScreen type
+ (BOOL)validateBuilder:(UAInAppMessageFullScreenDisplayContentBuilder *)builder {
    if (builder.heading == nil && builder.body == nil) {
        UA_LDEBUG(@"Full screen display must have either its body or heading defined.");
        return NO;
    }

    if (builder.buttons.count > UAInAppMessageFullScreenMaxButtons) {
        UA_LDEBUG(@"Full screen display allows a maximum of %lu buttons", (unsigned long)UAInAppMessageFullScreenMaxButtons);
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageFullScreenDisplayContent class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageFullScreenDisplayContent:(UAInAppMessageFullScreenDisplayContent *)object];
}

- (BOOL)isEqualToInAppMessageFullScreenDisplayContent:(UAInAppMessageFullScreenDisplayContent *)content {

    if (content.heading != self.heading && ![self.heading isEqual:content.heading]) {
        return NO;
    }

    if (content.body != self.body && ![self.body isEqual:content.body]) {
        return NO;
    }

    if (content.media != self.media  && ![self.media isEqual:content.media]) {
        return NO;
    }

    if (content.buttons != self.buttons  && ![self.buttons isEqualToArray:content.buttons]) {
        return NO;
    }

    if (content.footer != self.footer  && ![self.footer isEqual:content.footer]) {
        return NO;
    }

    if (content.buttonLayout != self.buttonLayout) {
        return NO;
    }

    if (content.contentLayout != self.contentLayout) {
        return NO;
    }

    // Unfortunately, UIColor won't compare across color spaces. It works to convert them to hex and then compare them.
    if (content.backgroundColor != self.backgroundColor && ![[UAColorUtils hexStringWithColor:self.backgroundColor] isEqualToString:[UAColorUtils hexStringWithColor:content.backgroundColor]]) {
        return NO;
    }
    
    if (content.dismissButtonColor != self.dismissButtonColor && ![[UAColorUtils hexStringWithColor:self.dismissButtonColor] isEqualToString:[UAColorUtils hexStringWithColor:content.dismissButtonColor]]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.heading hash];
    result = 31 * result + [self.body hash];
    result = 31 * result + [self.media hash];
    result = 31 * result + [self.buttons hash];
    result = 31 * result + [self.footer hash];
    result = 31 * result + self.buttonLayout;
    result = 31 * result + self.contentLayout;
    result = 31 * result + [[UAColorUtils hexStringWithColor:self.backgroundColor] hash];
    result = 31 * result + [[UAColorUtils hexStringWithColor:self.dismissButtonColor] hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageFullScreenDisplayContent: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

