/* Copyright 2017 Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo.h"
#import "UAInAppMessageButtonInfo.h"
#import "UAInAppMessageMediaInfo.h"
#import "UAInAppMessageDisplayContent.h"

NS_ASSUME_NONNULL_BEGIN

// JSON keys
NSString *const UAInAppMessageFullScreenActionsKey = @"actions";
NSString *const UAInAppMessageFullScreenDisplayContentDomain = @"com.urbanairship.full_screen_display_content";

NSString *const UAInAppMessageFullScreenContentLayoutHeaderMediaBody = @"header_media_body";
NSString *const UAInAppMessageFullScreenContentLayoutMediaHeaderBody = @"media_header_body";
NSString *const UAInAppMessageFullScreenContentLayoutHeaderBodyMedia = @"header_body_media";

// Constants
NSUInteger const UAInAppMessageFullScreenMaxButtons = 5;

@implementation UAInAppMessageFullScreenDisplayContentBuilder

- (BOOL)applyFromJSON:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    UAInAppMessageTextInfo *heading;
    if (json[UAInAppMessageHeadingKey]) {
        if (![json[UAInAppMessageHeadingKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }
        heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];
    }

    UAInAppMessageTextInfo *body;
    if (json[UAInAppMessageBodyKey]) {
        if (![json[UAInAppMessageBodyKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid text info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];
    }

    UAInAppMessageMediaInfo *media;
    if (json[UAInAppMessageMediaKey]) {
        if (![json[UAInAppMessageMediaKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        media = [UAInAppMessageMediaInfo mediaInfoWithJSON:json[UAInAppMessageMediaKey] error:error];
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

            return NO;
        }

        for (id buttonJSON in buttonsJSONArray) {
            UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithJSON:buttonJSON error:error];

            if (!buttonInfo) {
                return NO;
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
            return NO;
        }
    }

    id buttonLayout = json[UAInAppMessageButtonLayoutKey];
    if (buttonLayout && ![buttonLayout isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Button layout must be a string. Invalid value: %@", buttonLayout];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    NSString *contentLayout;
    id layoutContents = json[UAInAppMessageContentLayoutKey];
    if (layoutContents) {
        if (![layoutContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Content layout must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return NO;
        }

        NSString *layout = [layoutContents lowercaseString];

        if ([UAInAppMessageFullScreenContentLayoutMediaHeaderBody isEqualToString:layout]) {
            contentLayout = UAInAppMessageFullScreenContentLayoutMediaHeaderBody;
        } else if ([UAInAppMessageFullScreenContentLayoutHeaderMediaBody isEqualToString:layout]) {
            contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        } else if ([UAInAppMessageFullScreenContentLayoutHeaderBodyMedia isEqualToString:layout]) {
            contentLayout = UAInAppMessageFullScreenContentLayoutHeaderBodyMedia;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message content layout: %@", layout];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }
    }

    id backgroundColor = json[UAInAppMessageBackgroundColorKey];
    if (backgroundColor && ![backgroundColor isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Background color must be a string. Invalid value: %@", backgroundColor];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    id dismissButtonColor = json[UAInAppMessageDismissButtonColorKey];
    if (dismissButtonColor && ![dismissButtonColor isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Dismiss button color must be a string. Invalid value: %@", dismissButtonColor];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return NO;
    }

    UAInAppMessageButtonInfo *footer;
    if (json[UAInAppMessageFooterKey]) {
        if (![json[UAInAppMessageFooterKey] isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize media info object: %@", json];
                *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                              code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return NO;
        }

        footer = [UAInAppMessageButtonInfo buttonInfoWithJSON:json[UAInAppMessageFooterKey] error:error];
    }


    self.heading = heading;
    self.body = body;
    self.media = media;
    self.footer = footer;
    self.buttons = buttons;
    self.buttonLayout = buttonLayout;
    self.contentLayout = contentLayout;
    self.backgroundColor = backgroundColor;
    self.dismissButtonColor = dismissButtonColor;

    return YES;
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
    if (![builder applyFromJSON:json error:error]) {
        return nil;
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
        self.buttonLayout = builder.buttonLayout ?: UAInAppMessageButtonLayoutSeparate;
        if (self.buttons.count > 2) {
            self.buttonLayout = UAInAppMessageButtonLayoutStacked;
        }

        self.contentLayout = builder.contentLayout ?: UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        self.backgroundColor = builder.backgroundColor ?: @"#FFFFFF"; //White
        self.dismissButtonColor = builder.dismissButtonColor ?: @"#000000"; //Black
    }

    return self;
}

- (NSDictionary *)toJsonValue {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    if (!self) {
        return [NSDictionary dictionaryWithDictionary:json];
    }

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

    json[UAInAppMessageButtonLayoutKey] = self.buttonLayout;
    json[UAInAppMessageContentLayoutKey] = self.contentLayout;
    json[UAInAppMessageBackgroundColorKey] = self.backgroundColor;
    json[UAInAppMessageDismissButtonColorKey] = self.dismissButtonColor;

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

    if (content.buttonLayout != self.buttonLayout && ![self.buttonLayout isEqualToString:content.buttonLayout]) {
        return NO;
    }

    if (content.contentLayout != self.contentLayout  && ![self.contentLayout isEqualToString:content.contentLayout]) {
        return NO;
    }

    if (content.backgroundColor != self.backgroundColor && ![self.backgroundColor isEqualToString:content.backgroundColor]) {
        return NO;
    }

    if (content.dismissButtonColor != self.dismissButtonColor && ![self.dismissButtonColor isEqualToString:content.dismissButtonColor]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.heading hash];
    result = 31 * result + [self.body hash];
    result = 31 * result + [self.media hash];
    result = 31 * result + [self.footer hash];
    result = 31 * result + [self.buttons hash];
    result = 31 * result + [self.buttonLayout hash];
    result = 31 * result + [self.contentLayout hash];
    result = 31 * result + [self.backgroundColor hash];
    result = 31 * result + [self.dismissButtonColor hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageFullScreenDisplayContent: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

