/* Copyright Urban Airship and Contributors */

#import "UAirship.h"
#import "UAInAppMessageFullScreenDisplayContent+Internal.h"
#import "UAInAppMessageTextInfo+Internal.h"
#import "UAInAppMessageButtonInfo+Internal.h"
#import "UAInAppMessageMediaInfo+Internal.h"
#import "UAInAppMessageDisplayContent.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

// JSON keys
NSString *const UAInAppMessageFullScreenDisplayContentDomain = @"com.urbanairship.full_screen_display_content";

NSString *const UAInAppMessageFullScreenContentLayoutHeaderMediaBodyValue = @"header_media_body";
NSString *const UAInAppMessageFullScreenContentLayoutMediaHeaderBodyValue = @"media_header_body";
NSString *const UAInAppMessageFullScreenContentLayoutHeaderBodyMediaValue = @"header_body_media";

// Constants
NSUInteger const UAInAppMessageFullScreenMaxButtons = 5;

@implementation UAInAppMessageFullScreenDisplayContentBuilder

// set default values for properties
- (instancetype)init {
    self = [super init];

    if (self) {
        self.buttonLayout = UAInAppMessageButtonLayoutTypeSeparate;
        self.contentLayout = UAInAppMessageFullScreenContentLayoutHeaderMediaBody;
        self.backgroundColor = [UIColor whiteColor];
        self.dismissButtonColor = [UIColor blackColor];
    }

    return self;
}

- (instancetype)initWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)content {
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
    }

    return self;
}

+ (instancetype)builderWithDisplayContent:(UAInAppMessageFullScreenDisplayContent *)content {
    return [[self alloc] initWithDisplayContent:content];
}

- (BOOL)isValid {
    if (self.heading == nil && self.body == nil) {
        UA_LERR(@"Full screen display must have either its body or heading defined.");
        return NO;
    }

    if (self.buttons.count > UAInAppMessageFullScreenMaxButtons) {
        UA_LERR(@"Full screen display allows a maximum of %lu buttons", (unsigned long)UAInAppMessageFullScreenMaxButtons);
        return NO;
    }

    return YES;
}

@end

@interface UAInAppMessageFullScreenDisplayContent()
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *heading;
@property(nonatomic, strong, nullable) UAInAppMessageTextInfo *body;
@property(nonatomic, strong, nullable) UAInAppMessageMediaInfo *media;
@property(nonatomic, strong, nullable) UAInAppMessageButtonInfo *footer;
@property(nonatomic, strong, nullable) NSArray<UAInAppMessageButtonInfo *> *buttons;
@property(nonatomic, assign) UAInAppMessageButtonLayoutType buttonLayout;
@property(nonatomic, assign) UAInAppMessageFullScreenContentLayoutType contentLayout;
@property(nonatomic, strong) UIColor *backgroundColor;
@property(nonatomic, strong) UIColor *dismissButtonColor;
@end

@implementation UAInAppMessageFullScreenDisplayContent

+ (nullable instancetype)displayContentWithBuilderBlock:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock {
    UAInAppMessageFullScreenDisplayContentBuilder *builder = [[UAInAppMessageFullScreenDisplayContentBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageFullScreenDisplayContent alloc] initWithBuilder:builder];
}

+ (nullable instancetype)displayContentWithJSON:(id)json error:(NSError **)error {
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
    } else {
        // default is different if more than 2 buttons
        if (builder.buttons.count > 2) {
            builder.buttonLayout = UAInAppMessageButtonLayoutTypeStacked;
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
        builder.footer = [UAInAppMessageButtonInfo buttonInfoWithJSON:json[UAInAppMessageFooterKey] error:error];

        if (!builder.footer) {
            return nil;
        }
    }

    if (![builder isValid]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Invalid full screen display content: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageFullScreenDisplayContentDomain
                                          code:UAInAppMessageFullScreenDisplayContentErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    return [[UAInAppMessageFullScreenDisplayContent alloc] initWithBuilder:builder];
}

- (nullable instancetype)initWithBuilder:(UAInAppMessageFullScreenDisplayContentBuilder *)builder {
    self = [super init];

    if (![builder isValid]) {
        UA_LERR(@"UAInAppMessageFullScreenDisplayContent could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.heading = builder.heading;
        self.body = builder.body;
        self.media = builder.media;
        self.footer = builder.footer;
        self.buttons = builder.buttons;
        self.buttonLayout = builder.buttons.count > 2 ? UAInAppMessageButtonLayoutTypeStacked : builder.buttonLayout;
        self.contentLayout = builder.contentLayout;
        self.backgroundColor = builder.backgroundColor;
        self.dismissButtonColor = builder.dismissButtonColor;
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
        case UAInAppMessageFullScreenContentLayoutHeaderMediaBody:
            [json setValue:UAInAppMessageFullScreenContentLayoutHeaderMediaBodyValue forKey:UAInAppMessageContentLayoutKey];
            break;
        case UAInAppMessageFullScreenContentLayoutMediaHeaderBody:
            [json setValue:UAInAppMessageFullScreenContentLayoutMediaHeaderBodyValue forKey:UAInAppMessageContentLayoutKey];
            break;
        case UAInAppMessageFullScreenContentLayoutHeaderBodyMedia:
            [json setValue:UAInAppMessageFullScreenContentLayoutHeaderBodyMediaValue forKey:UAInAppMessageContentLayoutKey];
            break;
    }

    return [json copy];
}

- (nullable UAInAppMessageFullScreenDisplayContent *)extend:(void(^)(UAInAppMessageFullScreenDisplayContentBuilder *builder))builderBlock {
    if (builderBlock) {
        UAInAppMessageFullScreenDisplayContentBuilder *builder = [UAInAppMessageFullScreenDisplayContentBuilder builderWithDisplayContent:self];
        builderBlock(builder);
        return [[UAInAppMessageFullScreenDisplayContent alloc] initWithBuilder:builder];
    }

    UA_LDEBUG(@"Extended %@ with nil builderBlock. Returning self.", self);
    return self;
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
    return [NSString stringWithFormat:@"<UAInAppMessageFullScreenDisplayContent: %@>", [self toJSON]];
}

-(UAInAppMessageDisplayType)displayType {
    return UAInAppMessageDisplayTypeFullScreen;
}

@end

NS_ASSUME_NONNULL_END

