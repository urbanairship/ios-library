/* Copyright Urban Airship and Contributors */

#import "UAInAppMessageModalDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo+Internal.h"
#import "UAInAppMessageMediaInfo+Internal.h"
#import "UAInAppMessageButtonInfo+Internal.h"
#import "UAColorUtils+Internal.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

// JSON keys
NSString *const UAInAppMessageModalDisplayContentDomain = @"com.urbanairship.modal_display_content";

NSString *const UAInAppMessageModalContentLayoutHeaderMediaBodyValue = @"header_media_body";
NSString *const UAInAppMessageModalContentLayoutMediaHeaderBodyValue = @"media_header_body";
NSString *const UAInAppMessageModalContentLayoutHeaderBodyMediaValue = @"header_body_media";

// Constants
NSUInteger const UAInAppMessageModalMaxButtons = 2;

@implementation UAInAppMessageModalDisplayContentBuilder

// set default values for properties
- (instancetype)init {
    if (self = [super init]) {
        self.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        self.contentLayout = UAInAppMessageModalContentLayoutHeaderMediaBody;
        self.backgroundColor = [UIColor whiteColor];
        self.dismissButtonColor = [UIColor blackColor];
    }
    return self;
}

- (instancetype)initWithDisplayContent:(UAInAppMessageModalDisplayContent *)content {
    self = [super init];

    if (self) {
        self.heading = content.heading;
        self.body = content.body;
        self.media = content.media;
        self.footer = content.footer;
        self.buttons = content.buttons;
        self.buttonLayout = content.buttonLayout;
        self.contentLayout = content.contentLayout;
        self.backgroundColor = content.backgroundColor;
        self.dismissButtonColor = content.dismissButtonColor;
        self.borderRadiusPoints = content.borderRadiusPoints;
        self.allowFullScreenDisplay = content.allowFullScreenDisplay;
    }

    return self;
}

+ (instancetype)builderWithDisplayContent:(UAInAppMessageModalDisplayContent *)content {
    return [[self alloc] initWithDisplayContent:content];
}

- (BOOL)isValid {
    if (!self.heading && !self.body) {
        UA_LERR(@"Modal display must have either its body or heading defined.");
        return NO;
    }

    if (self.buttons.count > UAInAppMessageModalMaxButtons) {
        UA_LERR(@"Modal display allows a maximum of %lu buttons", (unsigned long)UAInAppMessageModalMaxButtons);
        return NO;
    }

    return YES;
}

- (NSUInteger)borderRadius {
    return self.borderRadiusPoints;
}

- (void)setBorderRadius:(NSUInteger)borderRadius {
    self.borderRadiusPoints = borderRadius;
}

@end

@interface UAInAppMessageModalDisplayContent()

@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;
@property(nonatomic, strong, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;
@property(nonatomic, assign) UAInAppMessageModalContentLayoutType contentLayout;
@property(nonatomic, strong) UIColor *backgroundColor;
@property(nonatomic, strong) UIColor *dismissButtonColor;
@property(nonatomic, assign) CGFloat borderRadiusPoints;
@property(nonatomic, assign) BOOL allowFullScreenDisplay;

@end

@implementation UAInAppMessageModalDisplayContent

+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageModalDisplayContentBuilder *builder))builderBlock {
    UAInAppMessageModalDisplayContentBuilder *builder = [[UAInAppMessageModalDisplayContentBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageModalDisplayContent alloc] initWithBuilder:builder];
}

+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageModalDisplayContentBuilder *builder = [[UAInAppMessageModalDisplayContentBuilder alloc] init];

    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                          code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }

    if (json[UAInAppMessageHeadingKey]) {
        builder.heading = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageHeadingKey] error:error];
        if (!builder.heading) {
            return nil;
        }
    }

    if (json[UAInAppMessageBodyKey]) {
        builder.body = [UAInAppMessageTextInfo textInfoWithJSON:json[UAInAppMessageBodyKey] error:error];
        if (!builder.body) {
            return nil;
        }
    }

    if (json[UAInAppMessageMediaKey]) {
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

        layoutContents = [layoutContents lowercaseString];

        if ([UAInAppMessageModalContentLayoutMediaHeaderBodyValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageModalContentLayoutMediaHeaderBody;
        } else if ([UAInAppMessageModalContentLayoutHeaderMediaBodyValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageModalContentLayoutHeaderMediaBody;
        } else if ([UAInAppMessageModalContentLayoutHeaderBodyMediaValue isEqualToString:layoutContents]) {
            builder.contentLayout = UAInAppMessageModalContentLayoutHeaderBodyMedia;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message content layout: %@", layoutContents];
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
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
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.dismissButtonColor = [UAColorUtils colorWithHexString:dismissButtonColor];
    }

    id borderRadius = json[UAInAppMessageBorderRadiusKey];
    if (borderRadius) {
        if (![borderRadius isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Border radius must be a number. Invalid value: %@", borderRadius];
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.borderRadiusPoints = [borderRadius doubleValue];
    }

    id allowFullScreenDisplay = json[UAInAppMessageModalAllowsFullScreenKey];
    if (allowFullScreenDisplay) {
        if (![allowFullScreenDisplay isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Allows full screen flag must be a boolean stored as an NSNumber. Invalid value: %@", allowFullScreenDisplay];
                *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                              code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.allowFullScreenDisplay = [allowFullScreenDisplay boolValue];
    }

    if (json[UAInAppMessageFooterKey]) {
        builder.footer = [UAInAppMessageButtonInfo buttonInfoWithJSON:json[UAInAppMessageFooterKey] error:error];

        if (!builder.footer) {
            return nil;
        }
    }

    if (![builder isValid]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid modal display content: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageModalDisplayContentDomain
                                          code:UAInAppMessageModalDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    return [[UAInAppMessageModalDisplayContent alloc] initWithBuilder:builder];}

- (nullable instancetype)initWithBuilder:(UAInAppMessageModalDisplayContentBuilder *)builder {
    self = [super init];

    if (![builder isValid]) {
        UA_LERR(@"UAInAppMessageModalDisplayContent could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.footer = builder.footer;
        self.buttons = builder.buttons;
        self.buttonLayout = builder.buttonLayout;
        self.contentLayout = builder.contentLayout;
        self.backgroundColor = builder.backgroundColor;
        self.dismissButtonColor = builder.dismissButtonColor;
        self.borderRadiusPoints = builder.borderRadiusPoints;
        self.allowFullScreenDisplay = builder.allowFullScreenDisplay;
    }

    return self;
}

- (NSDictionary *)toJSON {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    [json setValue:[self.heading toJSON] forKey:UAInAppMessageHeadingKey];
    [json setValue:[self.body toJSON] forKey:UAInAppMessageBodyKey];
    [json setValue:[self.media toJSON] forKey:UAInAppMessageMediaKey];
    [json setValue:[UAColorUtils hexStringWithColor:self.backgroundColor] forKey:UAInAppMessageBackgroundColorKey];
    [json setValue:[UAColorUtils hexStringWithColor:self.dismissButtonColor] forKey:UAInAppMessageDismissButtonColorKey];
    [json setValue:[self.footer toJSON] forKey:UAInAppMessageFooterKey];
    [json setValue:@(self.borderRadiusPoints) forKey:UAInAppMessageBorderRadiusKey];
    [json setValue:@(self.allowFullScreenDisplay) forKey:UAInAppMessageModalAllowsFullScreenKey];

    NSMutableArray *buttonsJSONs = [NSMutableArray array];
    for (UAInAppMessageButtonInfo *buttonInfo in self.buttons) {
        [buttonsJSONs addObject:[buttonInfo toJSON]];
    }

    if (buttonsJSONs.count) {
        [json setValue:buttonsJSONs forKey:UAInAppMessageButtonsKey];
    }

    switch (self.buttonLayout) {
        case UAInAppMessageButtonLayoutTypeStacked:
            [json setValue:UAInAppMessageButtonLayoutStackedValue forKey:UAInAppMessageButtonLayoutKey];
            break;
        case UAInAppMessageButtonLayoutTypeSeparate:
            [json setValue:UAInAppMessageButtonLayoutSeparateValue forKey:UAInAppMessageButtonLayoutKey];
            break;
        case UAInAppMessageButtonLayoutTypeJoined:
            [json setValue:UAInAppMessageButtonLayoutJoinedValue forKey:UAInAppMessageButtonLayoutKey];
            break;
    }

    switch (self.contentLayout) {
        case UAInAppMessageModalContentLayoutHeaderMediaBody:
            [json setValue:UAInAppMessageModalContentLayoutHeaderMediaBodyValue forKey:UAInAppMessageContentLayoutKey];
            break;
        case UAInAppMessageModalContentLayoutMediaHeaderBody:
            [json setValue:UAInAppMessageModalContentLayoutMediaHeaderBodyValue forKey:UAInAppMessageContentLayoutKey];
            break;
        case UAInAppMessageModalContentLayoutHeaderBodyMedia:
            [json setValue:UAInAppMessageModalContentLayoutHeaderBodyMediaValue forKey:UAInAppMessageContentLayoutKey];
            break;
    }

    return [json copy];
}

- (nullable UAInAppMessageModalDisplayContent *)extend:(void(^)(UAInAppMessageModalDisplayContentBuilder *builder))builderBlock {
    if (builderBlock) {
        UAInAppMessageModalDisplayContentBuilder *builder = [UAInAppMessageModalDisplayContentBuilder builderWithDisplayContent:self];
        builderBlock(builder);
        return [[UAInAppMessageModalDisplayContent alloc] initWithBuilder:builder];
    }

    UA_LDEBUG(@"Extended %@ with nil builderBlock. Returning self.", self);
    return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageModalDisplayContent class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageModalDisplayContent:(UAInAppMessageModalDisplayContent *)object];
}

- (BOOL)isEqualToInAppMessageModalDisplayContent:(UAInAppMessageModalDisplayContent *)content {

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

    if (![UAUtils float:self.borderRadiusPoints isEqualToFloat:content.borderRadiusPoints withAccuracy:0.01]) {
        return NO;
    }

    if (self.allowFullScreenDisplay != content.allowFullScreenDisplay) {
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
    result = 31 * result + self.borderRadiusPoints;
    result = 31 * result + self.allowFullScreenDisplay;

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<UAInAppMessageModalDisplayContent: %@>", [self toJSON]];
}

-(UAInAppMessageDisplayType)displayType {
    return UAInAppMessageDisplayTypeModal;
}

- (NSUInteger)borderRadius {
    return self.borderRadiusPoints;
}

@end

NS_ASSUME_NONNULL_END

