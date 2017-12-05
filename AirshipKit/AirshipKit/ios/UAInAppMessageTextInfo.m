/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
NSString *const UAInAppMessageTextInfoDomain = @"com.urbanairship.in_app_message_text_info";

NSString *const UAInAppMessageTextInfoAlignmentRight = @"right";
NSString *const UAInAppMessageTextInfoAlignmentCenter = @"center";
NSString *const UAInAppMessageTextInfoAlignmentLeft = @"left";

NSString *const UAInAppMessageTextInfoStyleBold = @"bold";
NSString *const UAInAppMessageTextInfoStyleItalic = @"italic";
NSString *const UAInAppMessageTextInfoStyleUnderline = @"underline";

// JSON keys
NSString *const UAInAppMessageTextInfoTextKey = @"text";
NSString *const UAInAppMessageTextInfoFontFamiliesKey = @"font_family";
NSString *const UAInAppMessageTextInfoColorKey = @"color";
NSString *const UAInAppMessageTextInfoSizeKey = @"size";
NSString *const UAInAppMessageTextInfoAlignmentKey = @"alignment";
NSString *const UAInAppMessageTextInfoStyleKey = @"style";

@interface UAInAppMessageTextInfo ()
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSArray<NSString *> *fontFamilies;
@property(nonatomic, copy) NSString *color;
@property(nonatomic, assign) NSUInteger size;
@property(nonatomic, copy) NSString *alignment;
@property(nonatomic, copy) NSArray<NSString *> *styles;
@end

@implementation UAInAppMessageTextInfoBuilder
@end

@implementation UAInAppMessageTextInfo

- (instancetype)initWithBuilder:(UAInAppMessageTextInfoBuilder *)builder {
    self = [super self];
    if (self) {
        self.text = builder.text;
        self.color = builder.color;
        self.size = builder.size;
        self.alignment = builder.alignment;
        self.styles = builder.styles;
        self.fontFamilies = builder.fontFamilies;
    }

    return self;
}

+ (nullable instancetype)textInfoWithBuilderBlock:(void(^)(UAInAppMessageTextInfoBuilder *builder))builderBlock {
    UAInAppMessageTextInfoBuilder *builder = [[UAInAppMessageTextInfoBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageTextInfo alloc] initWithBuilder:builder];
}

+ (nullable instancetype)textInfoWithJSON:(id)json error:(NSError * _Nullable *)error {
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    NSString *text;
    id textInfo = json[UAInAppMessageTextInfoTextKey];
    if (textInfo && ![textInfo isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message text info text must be a string. Invalid value: %@", textInfo];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    text = textInfo;

    NSString *color;
    id textColor = json[UAInAppMessageTextInfoColorKey];
    if (textColor && ![textColor isKindOfClass:[NSString class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message text color must be a hex string. Invalid value: %@", textColor];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    color = textColor;

    NSUInteger size;
    id textSize = json[UAInAppMessageTextInfoSizeKey];
    if (textSize && ![textSize isKindOfClass:[NSNumber class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"In-app message text size must be a number. Invalid value: %@", textSize];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }
    size = [textSize unsignedIntegerValue];

    NSString *alignment;
    if (json[UAInAppMessageTextInfoAlignmentKey]) {
        NSString *alignmentType = [json[UAInAppMessageTextInfoAlignmentKey] lowercaseString];

        if ([UAInAppMessageTextInfoAlignmentLeft isEqualToString:alignmentType]) {
            alignment = UAInAppMessageTextInfoAlignmentLeft;
        } else if ([UAInAppMessageTextInfoAlignmentCenter isEqualToString:alignmentType]) {
            alignment = UAInAppMessageTextInfoAlignmentCenter;
        } else if ([UAInAppMessageTextInfoAlignmentRight isEqualToString:alignmentType]) {
            alignment = UAInAppMessageTextInfoAlignmentRight;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message text alignment: %@", alignmentType];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    NSMutableArray *styles = [NSMutableArray array];
    id stylesArr = json[UAInAppMessageTextInfoStyleKey];
    if (stylesArr && ![stylesArr isKindOfClass:[NSArray class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Styles must be an array. Invalid value %@", stylesArr];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    for (id style in stylesArr) {
        if (![style isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"style types must be strings. Invalid value %@", style];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

        if ([UAInAppMessageTextInfoStyleBold isEqualToString:style]) {
            [styles addObject:UAInAppMessageTextInfoStyleBold];
        } else if ([UAInAppMessageTextInfoStyleItalic isEqualToString:style]) {
            [styles addObject:UAInAppMessageTextInfoStyleItalic];
        } else if ([UAInAppMessageTextInfoStyleUnderline isEqualToString:style]) {
            [styles addObject:UAInAppMessageTextInfoStyleUnderline];
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message style: %@", style];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    id fontFamilies = json[UAInAppMessageTextInfoFontFamiliesKey];
    if (fontFamilies && ![fontFamilies isKindOfClass:[NSArray class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Font families must be an array. Invalid value %@", fontFamilies];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }

        return nil;
    }

    for (id fontFamily in fontFamilies) {
        if (![fontFamily isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"A font family must be a string. Invalid value %@", fontFamily];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }

    return [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder * _Nonnull builder) {
        builder.text = text;
        builder.color = color;
        builder.size = size;
        builder.alignment = alignment;
        builder.fontFamilies = fontFamilies;
        builder.styles = styles;
    }];
}

+ (NSDictionary *)JSONWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageTextInfoTextKey] = textInfo.text;
    json[UAInAppMessageTextInfoFontFamiliesKey] = textInfo.fontFamilies;
    json[UAInAppMessageTextInfoColorKey] = textInfo.color;
    json[UAInAppMessageTextInfoSizeKey] = [NSNumber numberWithInteger:textInfo.size];
    json[UAInAppMessageTextInfoAlignmentKey] = textInfo.alignment;
    json[UAInAppMessageTextInfoStyleKey] = textInfo.styles;

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageTextInfo class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageTextInfo:(UAInAppMessageTextInfo *)object];
}

- (BOOL)isEqualToInAppMessageTextInfo:(UAInAppMessageTextInfo *)info {

    if (info.text != self.text && ![self.text isEqualToString:info.text]) {
        return NO;
    }

    if (info.color != self.color && ![self.color isEqualToString:info.color]) {
        return NO;
    }

    if (info.size != self.size && self.size != info.size) {
        return NO;
    }

    if (info.alignment != self.alignment && ![self.alignment isEqualToString:info.alignment]) {
        return NO;
    }

    if (info.styles != self.styles && ![self.styles isEqualToArray:info.styles]) {
        return NO;
    }

    if (info.fontFamilies != self.fontFamilies && ![self.fontFamilies isEqualToArray:info.fontFamilies]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.text hash];
    result = 31 * result + [self.color hash];
    result = 31 * result + self.size;
    result = 31 * result + [self.alignment hash];
    result = 31 * result + [self.styles hash];
    result = 31 * result + [self.fontFamilies hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageTextInfo: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

