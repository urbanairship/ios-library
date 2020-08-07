/* Copyright Airship and Contributors */

#import "UAURLAllowList.h"
#import "UAGlobal.h"
#import "UARuntimeConfig.h"

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

/**
 * Set of UAURLAllowListEntry objects.
 */
@property(nonatomic, strong) NSMutableSet *entries;
/**
 * Regex that matches valid URL allow list pattern entries
 */
@property(nonatomic, strong) NSRegularExpression *validPatternExpression;

@end

@implementation UAURLAllowList

- (instancetype)init {
    self = [super init];
    if (self) {
        self.entries = [NSMutableSet set];
    }
    return self;
}

+ (instancetype)allowListWithConfig:(UARuntimeConfig *)config {
    UAURLAllowList *URLAllowList = [[self alloc] init];

    [URLAllowList addEntry:@"https://*.urbanairship.com"];

    [URLAllowList addEntry:@"https://*.asnapieu.com"];

    // Add YouTube only for the open URL scope
    [URLAllowList addEntry:@"https://*.youtube.com" scope:UAURLAllowListScopeOpenURL];

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
- (NSString *)escapeRegexString:(NSString *)input escapingWildcards:(BOOL)escapingWildcards {


    // Regular expression characters. Used to escape any regular expression from the path and host.
    NSArray *specialCharacters = @[@"\\", @".", @"[", @"]", @"{", @"}", @"(", @")", @"^", @"$", @"?", @"+", @"|", @"*"];

    // Prefix all special characters with a backslash
    for (NSString *character in specialCharacters) {
        input = [input stringByReplacingOccurrencesOfString:character
                                                 withString:[@"\\" stringByAppendingString:character]];
    }

    // If wildcards are intended, transform them in to the appropriate regex pattern
    if (!escapingWildcards) {
        input = [input stringByReplacingOccurrencesOfString:@"\\*" withString:@".*"];
    }

    return input;
}

/**
 * Convenience method for getting a URL path using CoreFoundation, which
 * preserves trailing slashes.
 */
- (NSString *)cfPathForURL:(NSURL *)URL {
    if (!URL) {
        return nil;
    }

    return (__bridge_transfer NSString*)CFURLCopyPath((CFURLRef)URL);
}

/**
 * Generates matcher that compares a URL component (scheme/host/path) with a supplied regex
 */
- (UAURLAllowListMatcher)matcherForURLComponent:(NSString *)componentKey withRegexString:(nonnull NSString *)regexString {

    if (![regexString hasPrefix:@"^"]) {
        regexString = [@"^" stringByAppendingString:regexString];
    }
    if (![regexString hasSuffix:@"$"]) {
        regexString = [regexString stringByAppendingString:@"$"];
    }

    return ^BOOL(NSURL *URL){
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString
                                                                               options:0
                                                                                 error:nil];
        // NSRegularExpression chokes on nil input strings, so in that case convert it into an empty string
        NSString *component;

        // The NSURL path property silently strips trailing slashes
        if ([componentKey isEqualToString:@"path"]) {
            component = [self cfPathForURL:URL];
        } else {
            component = [URL valueForKey:componentKey];
        }

        component = component ?: @"";

        NSRange matchRange = [regex rangeOfFirstMatchInString:component options:0 range:NSMakeRange(0, component.length)];
        return matchRange.location != NSNotFound;
    };
}

- (UAURLAllowListMatcher)schemeMatcherForPattern:(NSString *)pattern {

    NSURL *URL = [NSURL URLWithString:pattern];

    if (!URL) {
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *scheme = URL.scheme;

    // NSURL won't parse strings with an actual asterisk for the scheme
    scheme = [scheme stringByReplacingOccurrencesOfString:@"WILDCARD" withString:@"*"];

    NSString *schemeRegexString;

    if (!scheme || !scheme.length || [scheme isEqualToString:@"*"]) {
        schemeRegexString = @".*";
    } else {
        schemeRegexString = [self escapeRegexString:scheme escapingWildcards:NO];
    }

    return [self matcherForURLComponent:@"scheme" withRegexString:schemeRegexString];
}

- (UAURLAllowListMatcher)hostMatcherForPattern:(NSString *)pattern {
    NSURL *URL = [NSURL URLWithString:pattern];

    if (!URL){
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *host = URL.host;

    NSString *hostRegexString;

    if (!host || [host isEqualToString:@"*"]) {
        hostRegexString = @".*";
    } else if ([host hasPrefix:@"*."]) {
        hostRegexString = [@"(.*\\.)?" stringByAppendingString:[self escapeRegexString:[host substringFromIndex:2]
                                                                     escapingWildcards:YES]];
    } else {
        hostRegexString = [self escapeRegexString:host escapingWildcards:YES];
    }

    return [self matcherForURLComponent:@"host" withRegexString:hostRegexString];
}

- (UAURLAllowListMatcher)pathMatcherForPattern:(NSString *)pattern {
    NSURL *URL = [NSURL URLWithString:pattern];

    if (!URL) {
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    // The NSURL path property silently strips trailing slashes
    NSString *path = [self cfPathForURL:URL];

    NSString *pathRegexString;

    if (!path || !path.length || [path isEqualToString:@"/*"]) {
        pathRegexString = @".*";
    } else {
        pathRegexString = [self escapeRegexString:path escapingWildcards:NO];
    }

    return [self matcherForURLComponent:@"path" withRegexString:pathRegexString];
}

- (UAURLAllowListMatcher)wildcardMatcher {
    return ^BOOL(NSURL *URL) {
        return YES;
    };
}

- (NSRegularExpression *)patternValidator:(NSString *)pattern {
    /**
     * Regular expression to match the scheme.
     * <scheme> := '*' | <valid scheme characters, `*` will match 0 or more characters>
     */
    NSString *schemeRegexString = @"([^\\s]+)";

    /**
     * Regular expression to match the host.
     * <host> := '*' | *.<valid host characters> | <valid host characters>
     */
    NSString *hostRegexString = @"((\\*)|(\\*\\.[^/\\*]+)|([^/\\*]+))";

    /**
     * Regular expression to match the path.
     * <path> := <any chars, `*` will match 0 or more characters>
     */
    NSString *pathRegexString =  @"(.*)";

    /**
     * Regular expression to match the pattern.
     * <pattern> := '*' | <scheme>://<host>/<path> | <scheme>://<host> | <scheme>:///<path> | <scheme>:/<path> | <scheme>:/
     */

    NSString *validPatternRegexString = [NSString stringWithFormat:@"^((\\*)|((%@://%@/%@)|(%@://%@)|(%@:/[^/]%@)|(%@:/)|(%@:///%@)))$",
                                         schemeRegexString, hostRegexString, pathRegexString,
                                         schemeRegexString, hostRegexString,
                                         schemeRegexString, pathRegexString,
                                         schemeRegexString,
                                         schemeRegexString, pathRegexString];

    NSRegularExpression *validPatternExpression = [NSRegularExpression regularExpressionWithPattern:validPatternRegexString
                                                                            options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                              error:nil];

    return validPatternExpression;
}

- (BOOL)validatePattern:(NSString *)pattern {
    NSRegularExpression *validator = [self patternValidator:pattern];

    NSUInteger matches = [validator numberOfMatchesInString:pattern
                                                    options:0
                                                      range:NSMakeRange(0, pattern.length)];
    return matches > 0;
}

- (NSString *)escapeSchemeWildcard:(NSString *)patternString {
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

- (BOOL)addEntry:(NSString *)patternString scope:(UAURLAllowListScope)scope {

    if (!patternString || ![self validatePattern:patternString]) {
        UA_LERR(@"Invalid URL allow list pattern: %@", patternString);
        return NO;
    }

    // NSURL won't parse strings with an actual asterisk for the scheme
    patternString = [self escapeSchemeWildcard:patternString];

    // If we have just a wildcard, match anything
    if ([patternString isEqualToString:@"*"]) {
        [self.entries addObject:[UAURLAllowListEntry entryWithMatcher:[self wildcardMatcher] scope:scope]];
        return YES;
    }

    // Build matchers for each relevant component (scheme/host/path) of the URL based on the pattern string
    UAURLAllowListMatcher schemeMatcher = [self schemeMatcherForPattern:patternString];
    UAURLAllowListMatcher hostMatcher = [self hostMatcherForPattern:patternString];
    UAURLAllowListMatcher pathMatcher = [self pathMatcherForPattern:patternString];

    // If any of these are nil, something went wrong
    if (!schemeMatcher || !hostMatcher || !pathMatcher) {
        UA_LERR(@"Unable to build pattern matchers for URL allow list entry: %@", patternString);
        return NO;
    }

    // The matcher that is stored in the URL allow list encompasses matching each component.
    // A URL matches if an only if all components match.
    UAURLAllowListMatcher patternMatcher = ^BOOL(NSURL *URL) {
        BOOL matchedScheme = schemeMatcher(URL);
        BOOL matchedHost = hostMatcher(URL);
        BOOL matchedPath = pathMatcher(URL);
        return matchedScheme && matchedHost && matchedPath;
    };

    [self.entries addObject:[UAURLAllowListEntry entryWithMatcher:[patternMatcher copy] scope:scope]];

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
