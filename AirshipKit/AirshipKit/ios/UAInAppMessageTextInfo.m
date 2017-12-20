/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageTextInfo.h"
#import <UIKit/UIKit.h>
#import "UAGlobal.h"
#import "UAColorUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN
NSString *const UAInAppMessageTextInfoDomain = @"com.urbanairship.in_app_message_text_info";

// JSON keys and values
NSString *const UAInAppMessageTextInfoTextKey = @"text";
NSString *const UAInAppMessageTextInfoFontFamiliesKey = @"font_family";
NSString *const UAInAppMessageTextInfoColorKey = @"color";
NSString *const UAInAppMessageTextInfoSizeKey = @"size";
NSString *const UAInAppMessageTextInfoAlignmentKey = @"alignment";
NSString *const UAInAppMessageTextInfoStyleKey = @"style";

NSString *const UAInAppMessageTextInfoAlignmentRightValue = @"right";
NSString *const UAInAppMessageTextInfoAlignmentCenterValue = @"center";
NSString *const UAInAppMessageTextInfoAlignmentLeftValue = @"left";

NSString *const UAInAppMessageTextInfoStyleBoldValue = @"bold";
NSString *const UAInAppMessageTextInfoStyleItalicValue = @"italic";
NSString *const UAInAppMessageTextInfoStyleUnderlineValue = @"underline";

@interface UAInAppMessageTextInfo ()
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSArray<NSString *> *fontFamilies;
@property(nonatomic, strong) UIColor *color;
@property(nonatomic, assign) NSUInteger size;
@property(nonatomic, assign) NSTextAlignment alignment;
@property(nonatomic, assign) UAInAppMessageTextInfoStyleType style;
@end

@implementation UAInAppMessageTextInfoBuilder

// set default values for properties
- (instancetype)init {
    if (self = [super init]) {
        self.color = [UIColor blackColor];
        self.size = 14;
        self.alignment = NSTextAlignmentLeft;
    }
    return self;
}

@end

@implementation UAInAppMessageTextInfo

- (instancetype)initWithBuilder:(UAInAppMessageTextInfoBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageTextInfo validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageTextInfo could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.text = builder.text;
        self.color = builder.color;
        self.size = builder.size;
        self.alignment = builder.alignment;
        self.style = builder.style;
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

+ (nullable instancetype)textInfoWithJSON:(id)json error:(NSError **)error {
    UAInAppMessageTextInfoBuilder *builder = [[UAInAppMessageTextInfoBuilder alloc] init];
    
    if (![json isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *msg = [NSString stringWithFormat:@"Attempted to deserialize invalid object: %@", json];
            *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                          code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                      userInfo:@{NSLocalizedDescriptionKey:msg}];
        }
        return nil;
    }
    
    id textInfo = json[UAInAppMessageTextInfoTextKey];
    if (textInfo) {
        if (![textInfo isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message text info text must be a string. Invalid value: %@", textInfo];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.text = textInfo;
    }
    
    id textColor = json[UAInAppMessageTextInfoColorKey];
    if (textColor) {
        if (![textColor isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message text color must be a hex string. Invalid value: %@", textColor];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.color = [UAColorUtils colorWithHexString:textColor];
    }
    
    id textSize = json[UAInAppMessageTextInfoSizeKey];
    if (textSize) {
        if (![textSize isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message text size must be a number. Invalid value: %@", textSize];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.size = [textSize unsignedIntegerValue];
    }

    id alignmentContents = json[UAInAppMessageTextInfoAlignmentKey];
    if (alignmentContents) {
        if (![alignmentContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Alignment must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        alignmentContents = [alignmentContents lowercaseString];
        
        if ([UAInAppMessageTextInfoAlignmentLeftValue isEqualToString:alignmentContents]) {
            builder.alignment = NSTextAlignmentLeft;
        } else if ([UAInAppMessageTextInfoAlignmentCenterValue isEqualToString:alignmentContents]) {
            builder.alignment = NSTextAlignmentCenter;
        } else if ([UAInAppMessageTextInfoAlignmentRightValue isEqualToString:alignmentContents]) {
            builder.alignment = NSTextAlignmentRight;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message text alignment: %@", alignmentContents];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
    }

    id stylesArr = json[UAInAppMessageTextInfoStyleKey];
    if (stylesArr) {
        if (![stylesArr isKindOfClass:[NSArray class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Styles must be an array. Invalid value %@", stylesArr];
                *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                              code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        
        for (id styleStr in stylesArr) {
            if (![styleStr isKindOfClass:[NSString class]]) {
                if (error) {
                    NSString *msg = [NSString stringWithFormat:@"style types must be strings. Invalid value %@", styleStr];
                    *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                                  code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                              userInfo:@{NSLocalizedDescriptionKey:msg}];
                }
                return nil;
            }
            
            if ([UAInAppMessageTextInfoStyleBoldValue isEqualToString:styleStr]) {
                builder.style |= UAInAppMessageTextInfoStyleBold;
            } else if ([UAInAppMessageTextInfoStyleItalicValue isEqualToString:styleStr]) {
                builder.style |= UAInAppMessageTextInfoStyleItalic;
            } else if ([UAInAppMessageTextInfoStyleUnderlineValue isEqualToString:styleStr]) {
                builder.style |= UAInAppMessageTextInfoStyleUnderline;
            } else {
                if (error) {
                    NSString *msg = [NSString stringWithFormat:@"Invalid in-app message style: %@", styleStr];
                    *error =  [NSError errorWithDomain:UAInAppMessageTextInfoDomain
                                                  code:UAInAppMessageTextInfoErrorCodeInvalidJSON
                                              userInfo:@{NSLocalizedDescriptionKey:msg}];
                }
                return nil;
            }
        }
    }

    id fontFamilies = json[UAInAppMessageTextInfoFontFamiliesKey];
    if (fontFamilies) {
        if (![fontFamilies isKindOfClass:[NSArray class]]) {
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
        builder.fontFamilies = fontFamilies;
    }

    return [[UAInAppMessageTextInfo alloc] initWithBuilder:builder];
}

+ (NSDictionary *)JSONWithTextInfo:(UAInAppMessageTextInfo *)textInfo {
    if (!textInfo) {
        return nil;
    }

    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageTextInfoTextKey] = textInfo.text;
    json[UAInAppMessageTextInfoFontFamiliesKey] = textInfo.fontFamilies;
    json[UAInAppMessageTextInfoColorKey] = [UAColorUtils hexStringWithColor:textInfo.color];
    json[UAInAppMessageTextInfoSizeKey] = [NSNumber numberWithInteger:textInfo.size];
    switch (textInfo.alignment) {
        case NSTextAlignmentLeft:
        default:
            json[UAInAppMessageTextInfoAlignmentKey] = UAInAppMessageTextInfoAlignmentLeftValue;
            break;
        case NSTextAlignmentCenter:
            json[UAInAppMessageTextInfoAlignmentKey] = UAInAppMessageTextInfoAlignmentCenterValue;
            break;
        case NSTextAlignmentRight:
            json[UAInAppMessageTextInfoAlignmentKey] = UAInAppMessageTextInfoAlignmentRightValue;
            break;
    }
    
    NSMutableArray<NSString *> *stylesAsJSON = [NSMutableArray array];
    if (textInfo.style & UAInAppMessageTextInfoStyleBold) {
        [stylesAsJSON addObject:UAInAppMessageTextInfoStyleBoldValue];
    }
    if (textInfo.style & UAInAppMessageTextInfoStyleItalic) {
        [stylesAsJSON addObject:UAInAppMessageTextInfoStyleItalicValue];
    }
    if (textInfo.style & UAInAppMessageTextInfoStyleUnderline) {
        [stylesAsJSON addObject:UAInAppMessageTextInfoStyleUnderlineValue];
    }
    json[UAInAppMessageTextInfoStyleKey] = stylesAsJSON;

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

// Validates builder contents for the media type
+ (BOOL)validateBuilder:(UAInAppMessageTextInfoBuilder *)builder {
    if (!builder.text) {
        UA_LDEBUG(@"In-app text infos require text");
        return NO;
    }

    return YES;
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

    if (info.color != self.color && ![[UAColorUtils hexStringWithColor:self.color] isEqualToString:[UAColorUtils hexStringWithColor:info.color]]) {
        return NO;
    }

    if (info.size != self.size && self.size != info.size) {
        return NO;
    }

    if (info.alignment != self.alignment) {
        return NO;
    }

    if (info.style != self.style) {
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
    result = 31 * result + self.alignment;
    result = 31 * result + self.style;
    result = 31 * result + [self.fontFamilies hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageTextInfo: %lu", (unsigned long)self.hash];
}

@end

NS_ASSUME_NONNULL_END

