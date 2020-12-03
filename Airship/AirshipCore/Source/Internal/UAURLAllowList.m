/* Copyright Airship and Contributors */

#import "UAURLAllowList.h"
#import "UAGlobal.h"
#import "UARuntimeConfig.h"

/**
 * <path> | <scheme> := <any chars (no spaces), `*` will match 0 or more characters>
 */
#define kUAURLAllowListPathRegexString @"^([^\\s]*)$"

/**
 * <scheme> := <any chars (no spaces), `*` will match 0 or more characters>
 */
#define kUAURLAllowListSchemeRegexString @"^([^\\s]*)$"

/**
 * <host> := '*' | *.<valid host characters> | <valid host characters>
 */
#define kUAURLAllowListHostRegexString @"^((\\*)|(\\*\\.[^/\\*]+)|([^/\\*]+))$"

/**
 * Regular expression to escape from a pattern
 */
#define kUAURLAllowListEscapeRegexCharacters @[@"\\", @".", @"[", @"]", @"{", @"}", @"(", @")", @"^", @"$", @"?", @"+", @"|", @"*"]

/**
 * Block mapping URLs to allow list status
 */
typedef BOOL (^UAURLAllowListMatcher)(NSURL *);

@interface UAURLAllowListEntry : NSObject

@property(nonatomic, assign) UAURLAllowListScope scope;
@property(nonatomic, copy) UAURLAllowListMatcher matcher;

+ (instancetype)entryWithMatcher:(UAURLAllowListMatcher)matcher scope:(UAURLAllowListScope)scope;

@end

@implementation UAURLAllowListEntry

+ (instancetype)entryWithMatcher:(UAURLAllowListMatcher)matcher scope:(UAURLAllowListScope)scope {
    return [[self alloc] initWithMatcher:matcher scope:scope];
}

- (instancetype)initWithMatcher:(UAURLAllowListMatcher)matcher scope:(UAURLAllowListScope)scope {
    self = [super init];

    if (self) {
        self.matcher = matcher;
        self.scope = scope;
    }

    return self;
}

@end

@interface UAURLAllowList ()
@property(nonatomic, strong) NSMutableSet *entries;
@property(nonatomic, strong) NSRegularExpression *schemePatternValidator;
@property(nonatomic, strong) NSRegularExpression *hostPatternValidator;
@property(nonatomic, strong) NSRegularExpression *pathPatternValidator;
@end

@implementation UAURLAllowList

- (instancetype)init {
    self = [super init];
    if (self) {
        self.entries = [NSMutableSet set];

        self.schemePatternValidator = [NSRegularExpression regularExpressionWithPattern:kUAURLAllowListSchemeRegexString
                                                                                options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                                  error:nil];

        self.hostPatternValidator = [NSRegularExpression regularExpressionWithPattern:kUAURLAllowListHostRegexString
                                                                              options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                                error:nil];

        self.pathPatternValidator = [NSRegularExpression regularExpressionWithPattern:kUAURLAllowListPathRegexString
                                                                              options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                                error:nil];
    }
    return self;
}

+ (instancetype)allowListWithConfig:(UARuntimeConfig *)config {
    UAURLAllowList *URLAllowList = [[self alloc] init];
    [URLAllowList addEntry:@"https://*.urbanairship.com"];
    [URLAllowList addEntry:@"https://*.asnapieu.com"];

    // Open only
    [URLAllowList addEntry:@"https://*.youtube.com" scope:UAURLAllowListScopeOpenURL];
    [URLAllowList addEntry:@"mailto:*" scope:UAURLAllowListScopeOpenURL];
    [URLAllowList addEntry:@"sms:*" scope:UAURLAllowListScopeOpenURL];

    for (NSString *pattern in config.URLAllowList) {
        [URLAllowList addEntry:pattern];
    }
    
    for (NSString *pattern in config.URLAllowListScopeJavaScriptInterface) {
        [URLAllowList addEntry:pattern scope:UAURLAllowListScopeJavaScriptInterface];
    }
    
    for (NSString *pattern in config.URLAllowListScopeOpenURL) {
        [URLAllowList addEntry:pattern scope:UAURLAllowListScopeOpenURL];
    }

    return URLAllowList;
}

/**
 * Escapes URL allow list pattern strings so that they don't contain unanticipated regex characters
 */
+ (NSString *)escapeRegexString:(NSString *)input escapingWildcards:(BOOL)escapingWildcards {

    // Prefix all special characters with a backslash
    for (NSString *character in kUAURLAllowListEscapeRegexCharacters) {
        input = [input stringByReplacingOccurrencesOfString:character
                                                 withString:[@"\\" stringByAppendingString:character]];
    }

    // If wildcards are intended, transform them in to the appropriate regex pattern
    if (!escapingWildcards) {
        input = [input stringByReplacingOccurrencesOfString:@"\\*" withString:@".*"];
    }

    return input;
}

+ (BOOL)validatePattern:(NSString *)pattern expression:(NSRegularExpression *)expression {
    NSUInteger matches = [expression numberOfMatchesInString:pattern
                                                     options:0
                                                       range:NSMakeRange(0, pattern.length)];
    return matches > 0;
}

+ (NSString *)escapeSchemeWildcard:(NSString *)patternString {
    NSArray *components = [patternString componentsSeparatedByString:@":"];

    if (components.count > 1) {
        NSString *schemeComponent = components.firstObject;
        schemeComponent = [schemeComponent stringByReplacingOccurrencesOfString:@"*" withString:@"WILDCARD"];
        NSMutableArray *array = [NSMutableArray arrayWithObject:schemeComponent];
        [array addObjectsFromArray:[components subarrayWithRange:NSMakeRange(1, components.count - 1)]];
        return [array componentsJoinedByString:@":"];
    }

    return patternString;
}

+ (NSRegularExpression *)compilePattern:(NSString *)regexString {
    if (![regexString hasPrefix:@"^"]) {
        regexString = [@"^" stringByAppendingString:regexString];
    }
    if (![regexString hasSuffix:@"$"]) {
        regexString = [regexString stringByAppendingString:@"$"];
    }

    return [NSRegularExpression regularExpressionWithPattern:regexString
                                                     options:0
                                                       error:nil];
}

- (UAURLAllowListMatcher)matcherForScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path {
    NSRegularExpression *schemeRegEx;
    if (!scheme.length || [scheme isEqualToString:@"*"]) {
        schemeRegEx = nil;
    } else {
        schemeRegEx = [UAURLAllowList compilePattern:[UAURLAllowList escapeRegexString:scheme escapingWildcards:NO]];
    }

    NSRegularExpression *hostRegEx;
    if (!host.length || [host isEqualToString:@"*"]) {
        hostRegEx = nil;
    } else if ([host hasPrefix:@"*."]) {
        NSString *regExString = [@"(.*\\.)?" stringByAppendingString:[UAURLAllowList escapeRegexString:[host substringFromIndex:2]
                                                                                     escapingWildcards:YES]];
        hostRegEx = [UAURLAllowList compilePattern:regExString];
    } else {
        hostRegEx = [UAURLAllowList compilePattern:[UAURLAllowList escapeRegexString:host escapingWildcards:YES]];
    }

    NSRegularExpression *pathRegEx;
    if (!path.length || [path isEqualToString:@"/*"] || [path isEqualToString:@"*"]) {
        pathRegEx = nil;
    } else {
        pathRegEx = [UAURLAllowList compilePattern:[UAURLAllowList escapeRegexString:path escapingWildcards:NO]];
    }

    return ^BOOL(NSURL *URL) {

        if (schemeRegEx && (!URL.scheme.length || ![UAURLAllowList validatePattern:URL.scheme expression:schemeRegEx])) {
            return false;
        }

        if (hostRegEx && (!URL.host.length || ![UAURLAllowList validatePattern:URL.host expression:hostRegEx])) {
            return false;
        }

        NSString *path = [UAURLAllowList pathForURL:URL];
        if (pathRegEx && (!path.length || ![UAURLAllowList validatePattern:path expression:pathRegEx])) {
            return false;
        }

        return YES;
    };
}

+ (NSString *)pathForURL:(NSURL *)URL {
    if (!URL) {
        return nil;
    }

    // URL path using CoreFoundation, which preserves trailing slashes.
    NSString *path = (__bridge_transfer NSString*)CFURLCopyPath((CFURLRef)URL);

    // If the path is nil then its nonstandard, use the resourceSpecifier as path
    return path ?: URL.resourceSpecifier;
}

- (BOOL)addEntry:(NSString *)patternString scope:(UAURLAllowListScope)scope {
    if (!patternString.length) {
        UA_LERR(@"Invalid URL allow list pattern: %@", patternString);
        return NO;
    }

    // NSURL won't parse strings with an actual asterisk for the scheme * -> WILDCARD
    patternString = [UAURLAllowList escapeSchemeWildcard:patternString];

    // If we have just a wildcard, match anything
    if ([patternString isEqualToString:@"*"]) {
        UAURLAllowListEntry *entry = [UAURLAllowListEntry entryWithMatcher:[self matcherForScheme:nil host:nil path:nil]
                                                                     scope:scope];
        [self.entries addObject:entry];
        return YES;
    }

    NSURL *URL = [NSURL URLWithString:patternString];
    if (!URL) {
        UA_LERR(@"Unable to parse URL for pattern %@", patternString);
        return NO;
    }

    // Scheme WILDCARD -> *
    NSString *scheme = [URL.scheme stringByReplacingOccurrencesOfString:@"WILDCARD" withString:@"*"];
    if (!scheme.length || ![UAURLAllowList validatePattern:scheme expression:self.schemePatternValidator]) {
        UA_LERR(@"Invalid scheme %@ in URL allow list pattern %@", scheme, patternString);
        return NO;
    }

    NSString *host = URL.host;
    if (host.length && ![UAURLAllowList validatePattern:host expression:self.hostPatternValidator]) {
        UA_LERR(@"Invalid host %@ in URL allow list pattern %@", host, patternString);
        return NO;
    }

    NSString *path = [UAURLAllowList pathForURL:URL];
    if (path.length && ![UAURLAllowList validatePattern:path expression:self.pathPatternValidator]) {
        UA_LERR(@"Invalid path %@ in URL allow list pattern %@", path, patternString);
        return NO;
    }

    UAURLAllowListEntry *entry = [UAURLAllowListEntry entryWithMatcher:[self matcherForScheme:scheme host:host path:path]
                                                                 scope:scope];
    [self.entries addObject:entry];
    return YES;
}


- (BOOL)addEntry:(NSString *)patternString {
    return [self addEntry:patternString scope:UAURLAllowListScopeAll];
}

- (BOOL)isAllowed:(NSURL *)URL scope:(UAURLAllowListScope)scope {
    BOOL match = NO;
    
    
    NSUInteger matchedScope = 0;
    
    for (UAURLAllowListEntry *entry in self.entries) {
        if (entry.matcher(URL)) {
            matchedScope |= entry.scope;
        }
    }
    
    match = (((UAURLAllowListScope)matchedScope & scope) == scope);
    
    // if the URL is allowed, allow the delegate to reject the URL
    if (match) {
        id<UAURLAllowListDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(allowURL:scope:)]) {
            match = [delegate allowURL:URL scope:scope];
        }
    }
    
    return match;
}

- (BOOL)isAllowed:(NSURL *)URL {
    return [self isAllowed:URL scope:UAURLAllowListScopeAll];
}

@end
