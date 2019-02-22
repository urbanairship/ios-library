/* Copyright Urban Airship and Contributors */


#import "UAVersionMatcher+Internal.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"

typedef NS_ENUM(NSInteger,UAVersionMatcherConstraintType) {
    UAVersionMatcherConstraintTypeUnknown,
    UAVersionMatcherConstraintTypeExactVersion,
    UAVersionMatcherConstraintTypeSubVersion,
    UAVersionMatcherConstraintTypeVersionRange
};

@interface UAVersionMatcher ()

@property(nonatomic, strong) NSString *versionConstraint;
@property(nonatomic, assign) UAVersionMatcherConstraintType constraintType;
@property(nonatomic, strong) NSDictionary *parsedConstraint;

@end


@implementation UAVersionMatcher

#pragma mark -
#pragma mark Matcher factory

- (instancetype)init {
    if ((self = [super init])) {
        self.constraintType = UAVersionMatcherConstraintTypeUnknown;
    }
    return self;
}

+ (nullable instancetype)matcherWithVersionConstraint:(NSString *)versionConstraint {
    if (![versionConstraint isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    NSString *strippedVersionConstraint = [self removeWhitespace:versionConstraint];
    
    UAVersionMatcher *matcher = [[UAVersionMatcher alloc] init];
    matcher.versionConstraint = versionConstraint;
    
    NSDictionary *parsedConstraint = [self parseExactVersionConstraint:strippedVersionConstraint];
    if (parsedConstraint) {
        matcher.constraintType = UAVersionMatcherConstraintTypeExactVersion;
        matcher.parsedConstraint = parsedConstraint;
        return matcher;
    }
    
    parsedConstraint = [self parseSubVersionConstraint:strippedVersionConstraint];
    if (parsedConstraint) {
        matcher.constraintType = UAVersionMatcherConstraintTypeSubVersion;
        matcher.parsedConstraint = parsedConstraint;
        return matcher;
    }
    
    parsedConstraint = [self parseVersionRangeConstraint:strippedVersionConstraint];
    if (parsedConstraint) {
        matcher.constraintType = UAVersionMatcherConstraintTypeVersionRange;
        matcher.parsedConstraint = parsedConstraint;
        return matcher;
    }
    
    return nil;
}

#pragma mark -
#pragma mark Evaluate version against constraint

- (BOOL)evaluateObject:(id)value {
    NSString *checkVersion = [[self class] removeWhitespace:value];

    switch (self.constraintType) {
        case UAVersionMatcherConstraintTypeExactVersion:
            return [self versionMatchesExactVersion:checkVersion];
        case UAVersionMatcherConstraintTypeSubVersion:
            return [self versionMatchesSubVersion:checkVersion];
        case UAVersionMatcherConstraintTypeVersionRange:
            return [self versionMatchesRange:checkVersion];
        default:
            return NO;
    }
}

#pragma mark -
#pragma mark Exact Version Matcher

#define EXACT_VERSION_PATTERN @"^([0-9]+)(\\.[0-9]+)?(\\.[0-9]+)?$"

+ (BOOL)isExactVersion:(NSString *)versionConstraint {
    return ([self parseExactVersionConstraint:versionConstraint] != nil);
}

+ (NSDictionary *)parseExactVersionConstraint:(NSString *)versionConstraint {
    versionConstraint = [self removeWhitespace:versionConstraint];

    NSArray<NSTextCheckingResult *> *matches = [self getMatchesForPattern:EXACT_VERSION_PATTERN onString:versionConstraint];
    if (!matches || (matches.count != 1)) {
        return nil;
    }
    
    return @{
             @"exactVersion":versionConstraint
             };
}

- (BOOL)versionMatchesExactVersion:(NSString *)checkVersion {
    if (self.constraintType != UAVersionMatcherConstraintTypeExactVersion) {
        return NO;
    }
    
    return ([checkVersion isEqualToString:self.parsedConstraint[@"exactVersion"]]);
}

#pragma mark -
#pragma mark SubVersion Matcher

#define SUB_VERSION_PATTERN @"^(.*)\\+$"

+ (BOOL)isSubVersion:(NSString *)versionConstraint {
    return ([self parseSubVersionConstraint:versionConstraint] != nil);
}

+ (NSDictionary *)parseSubVersionConstraint:(NSString *)versionConstraint {
    versionConstraint = [self removeWhitespace:versionConstraint];

    NSArray<NSTextCheckingResult *> *matches = [self getMatchesForPattern:SUB_VERSION_PATTERN onString:versionConstraint];
    if (!matches || (matches.count != 1)) {
        return nil;
    }
    
    NSString *versionNumberPart = [versionConstraint substringWithRange:[matches[0] rangeAtIndex:1]];
    
    NSDictionary *parsedConstraint = @{
                                       @"subVersion":versionNumberPart
                                       };
    
    // allows "1.2+"
    if ([self isExactVersion:versionNumberPart]) {
        return parsedConstraint;
    }
    
    // allows "1.2.+"
    if ([self isExactVersion:[versionNumberPart stringByAppendingString:@"0"]]) {
        return parsedConstraint;
    }
    
    return nil;
}

- (BOOL)versionMatchesSubVersion:(NSString *)checkVersion {
    if (self.constraintType != UAVersionMatcherConstraintTypeSubVersion) {
        return NO;
    }
    
    NSString *subVersion = self.parsedConstraint[@"subVersion"];
    
    // if the version being matched is longer than the constraint, only compare its prefix
    if ([checkVersion length] > [subVersion length]) {
        return ([subVersion isEqualToString:[checkVersion substringToIndex:[subVersion length]]]);
    } else {
        return ([subVersion isEqualToString:checkVersion]);
    }
}

#pragma mark -
#pragma mark Version Range Matcher

#define START_INCLUSIVE     @"["
#define START_EXCLUSIVE     @"]"
#define START_INFINITE      @"("
#define END_INCLUSIVE       @"]"
#define END_EXCLUSIVE       @"["
#define END_INFINITE        @")"
#define RANGE_SEPARATOR     @","
#define ESCAPE_CHAR         @"\\"
#define START_TOKENS        ESCAPE_CHAR START_INCLUSIVE ESCAPE_CHAR START_EXCLUSIVE ESCAPE_CHAR START_INFINITE
#define END_TOKENS          ESCAPE_CHAR END_INCLUSIVE ESCAPE_CHAR END_EXCLUSIVE ESCAPE_CHAR END_INFINITE
#define START_END_TOKENS    START_TOKENS END_TOKENS
#define START_PATTERN       @"([" START_TOKENS @"])"
#define END_PATTERN         @"([" END_TOKENS @"])"
#define SEPARATOR_PATTERN   @"(" RANGE_SEPARATOR @")"
#define VERSION_PATTERN     @"([^" START_END_TOKENS RANGE_SEPARATOR @"]*)"
#define VERSION_RANGE_PATTERN START_PATTERN VERSION_PATTERN SEPARATOR_PATTERN VERSION_PATTERN END_PATTERN

typedef NS_ENUM(NSInteger,UAVersionMatcherRangeBoundary) {
    UAVersionMatcherRangeBoundaryInclusive,
    UAVersionMatcherRangeBoundaryExclusive,
    UAVersionMatcherRangeBoundaryInfinite
};

+ (BOOL)isVersionRange:(NSString *)versionConstraint {
    return ([self parseVersionRangeConstraint:versionConstraint] != nil);
}

+ (NSDictionary *)parseVersionRangeConstraint:(NSString *)versionConstraint {
    typedef NS_ENUM(NSInteger,UAVersionRangeMatcherTokenPosition) {
        UAVersionRangeMatcherTokenStartBoundary = 0,
        UAVersionRangeMatcherTokenStartVersion = 1,
        UAVersionRangeMatcherTokenSeparator = 2,
        UAVersionRangeMatcherTokenEndVersion = 3,
        UAVersionRangeMatcherTokenEndBoundary = 4
    };
    
    versionConstraint = [self removeWhitespace:versionConstraint];

    NSArray<NSTextCheckingResult *> *matches = [UAVersionMatcher getMatchesForPattern:VERSION_RANGE_PATTERN onString:versionConstraint];
    if ((matches.count != 1)) {
        return nil;
    }
    
    // extract tokens from version constraint
    NSTextCheckingResult *match = matches[0];
    NSUInteger numberOfTokens = match.numberOfRanges - 1;
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    for (NSUInteger index = 1;index <= numberOfTokens;index++) {
        NSString *token = [versionConstraint substringWithRange:[match rangeAtIndex:index]];
        [tokens addObject:token];
    }
    
    if (numberOfTokens != UAVersionRangeMatcherTokenEndBoundary + 1) {
        return nil;
    }
    
    // first token
    UAVersionMatcherRangeBoundary startBoundary;
    if ([tokens[UAVersionRangeMatcherTokenStartBoundary] isEqualToString:START_INCLUSIVE]) {
        startBoundary = UAVersionMatcherRangeBoundaryInclusive;
    } else if ([tokens[UAVersionRangeMatcherTokenStartBoundary] isEqualToString:START_EXCLUSIVE]) {
        startBoundary = UAVersionMatcherRangeBoundaryExclusive;
    } else if ([tokens[UAVersionRangeMatcherTokenStartBoundary] isEqualToString:START_INFINITE]) {
        startBoundary = UAVersionMatcherRangeBoundaryInfinite;
    } else {
        return nil;
    }
    
    NSString *startOfRange = ([tokens[UAVersionRangeMatcherTokenStartVersion] length] == 0) ? nil : tokens[1];
    
    // infinite boundary, and only infinite boundary, can have empty associated value
    if (startBoundary == UAVersionMatcherRangeBoundaryInfinite) {
        if (startOfRange) {
            return nil;
        }
    } else {
        if (!startOfRange) {
            return nil;
        }
    }
    
    // separator
    if (![tokens[UAVersionRangeMatcherTokenSeparator] isEqualToString:RANGE_SEPARATOR]) {
        return nil;
    }
    
    // ending version value
    UAVersionMatcherRangeBoundary endBoundary;
    if ([tokens[UAVersionRangeMatcherTokenEndBoundary] isEqualToString:END_INCLUSIVE]) {
        endBoundary = UAVersionMatcherRangeBoundaryInclusive;
    } else if ([tokens[UAVersionRangeMatcherTokenEndBoundary] isEqualToString:END_EXCLUSIVE]) {
        endBoundary = UAVersionMatcherRangeBoundaryExclusive;
    } else if ([tokens[UAVersionRangeMatcherTokenEndBoundary] isEqualToString:END_INFINITE]) {
        endBoundary = UAVersionMatcherRangeBoundaryInfinite;
    } else {
        return nil;
    }
    
    NSString *endOfRange = ([tokens[UAVersionRangeMatcherTokenEndVersion] length] == 0) ? nil : tokens[UAVersionRangeMatcherTokenEndVersion];
    
    // infinite boundary, and only infinite boundary, can have empty associated value
    if (endBoundary == UAVersionMatcherRangeBoundaryInfinite) {
        if (endOfRange) {
            return nil;
        }
    } else {
        if (!endOfRange) {
            return nil;
        }
    }
    
    // can't have infinite boundary at both start and end
    if ((startBoundary == UAVersionMatcherRangeBoundaryInfinite) && (endBoundary == UAVersionMatcherRangeBoundaryInfinite)) {
        return nil;
    }
    
    NSDictionary *parsedConstraint = @{
                                       @"startBoundary":@(startBoundary),
                                       @"endBoundary":@(endBoundary),
                                       @"startOfRange":startOfRange ?: [NSNull null],
                                       @"endOfRange":endOfRange ?: [NSNull null]
                                       };
    
    return parsedConstraint;
}

- (BOOL)versionMatchesRange:(NSString *)checkVersion {
    if (self.constraintType != UAVersionMatcherConstraintTypeVersionRange) {
        return NO;
    }
    
    UAVersionMatcherRangeBoundary startBoundary = [self.parsedConstraint[@"startBoundary"] integerValue];
    NSString *startOfRange = self.parsedConstraint[@"startOfRange"];
    if (startBoundary != UAVersionMatcherRangeBoundaryInfinite) {
        NSComparisonResult result = [UAUtils compareVersion:startOfRange toVersion:checkVersion];
        switch (startBoundary) {
            case UAVersionMatcherRangeBoundaryInclusive:
                if (result != NSOrderedAscending && result != NSOrderedSame) {
                    return NO;
                }
                break;
            case UAVersionMatcherRangeBoundaryExclusive:
                if (result != NSOrderedAscending) {
                    return NO;
                }
                break;
            default:
                return NO;
        }
    }
    
    UAVersionMatcherRangeBoundary endBoundary = [self.parsedConstraint[@"endBoundary"] integerValue];
    NSString *endOfRange = self.parsedConstraint[@"endOfRange"];
    if (endBoundary != UAVersionMatcherRangeBoundaryInfinite) {
        NSComparisonResult result = [UAUtils compareVersion:checkVersion toVersion:endOfRange];
        switch (endBoundary) {
            case UAVersionMatcherRangeBoundaryInclusive:
                if (result != NSOrderedAscending && result != NSOrderedSame) {
                    return NO;
                }
                break;
            case UAVersionMatcherRangeBoundaryExclusive:
                if (result != NSOrderedAscending) {
                    return NO;
                }
                break;
            default:
                return NO;
        }
    }
    
    return YES;
}

#pragma mark -
#pragma mark Utility methods

+ (NSArray<NSTextCheckingResult *> *)getMatchesForPattern:(NSString *)pattern onString:(NSString *)string {
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:NULL];
    
    if (error) {
        UA_LERR(@"Error creating regular expression - %@",error);
        return nil;
    }
    
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    return matches;
}

+ (NSString *)removeWhitespace:(NSString *)sourceString {
    NSString *destString = [sourceString stringByReplacingOccurrencesOfString:@"\\s"
                                                                   withString:@""
                                                                      options:NSRegularExpressionSearch
                                                                        range:NSMakeRange(0, [sourceString length])];
    return destString;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    
    if (![other isKindOfClass:[self class]]) {
        return NO;
    }
    
    return [self isEqualToVersionMatcher:(UAVersionMatcher *)other];
}

- (BOOL)isEqualToVersionMatcher:(nullable UAVersionMatcher *)matcher {
    if (self.constraintType != matcher.constraintType) {
        return NO;
    }
    if ((self.parsedConstraint != matcher.parsedConstraint) && ![self.parsedConstraint isEqual:matcher.parsedConstraint]) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + self.constraintType;
    result = 31 * result + [self.parsedConstraint hash];
    return result;
}

@end
