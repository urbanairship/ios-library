/* Copyright Urban Airship and Contributors */

#import "UAWhitelist.h"
#import "UAGlobal.h"
#import "UAConfig.h"

/**
 * Block mapping URLs to whitelist status
 */
typedef BOOL (^UAWhitelistMatcher)(NSURL *);

@interface UAWhitelistEntry : NSObject

@property(nonatomic, assign) UAWhitelistScope scope;
@property(nonatomic, copy) UAWhitelistMatcher matcher;

+ (instancetype)entryWithMatcher:(UAWhitelistMatcher)matcher scope:(UAWhitelistScope)scope;

@end

@implementation UAWhitelistEntry

+ (instancetype)entryWithMatcher:(UAWhitelistMatcher)matcher scope:(UAWhitelistScope)scope {
    return [[self alloc] initWithMatcher:matcher scope:scope];
}

- (instancetype)initWithMatcher:(UAWhitelistMatcher)matcher scope:(UAWhitelistScope)scope {
    self = [super init];

    if (self) {
        self.matcher = matcher;
        self.scope = scope;
    }

    return self;
}

@end

@interface UAWhitelist ()

/**
 * Set of UAWhitelistEntry objects.
 */
@property(nonatomic, strong) NSMutableSet *entries;
/**
 * Regex that matches valid whitelist pattern entries
 */
@property(nonatomic, strong) NSRegularExpression *validPatternExpression;

@end

@implementation UAWhitelist

- (instancetype)init {
    self = [super init];
    if (self) {
        self.entries = [NSMutableSet set];
        self.openURLWhitelistingEnabled = YES;
    }
    return self;
}

+ (instancetype)whitelistWithConfig:(UAConfig *)config {
    UAWhitelist *whitelist = [[self alloc] init];

    [whitelist addEntry:@"https://*.urbanairship.com"];

    // Add YouTube only for the open URL scope
    [whitelist addEntry:@"https://*.youtube.com" scope:UAWhitelistScopeOpenURL];

    for (NSString *pattern in config.whitelist) {
        [whitelist addEntry:pattern];
    }

    whitelist.openURLWhitelistingEnabled = config.isOpenURLWhitelistingEnabled;

    return whitelist;
}

/**
 * Escapes whitelist pattern strings so that they don't contain unanticipated regex characters
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
- (NSString *)cfPathForURL:(NSURL *)url {
    if (!url) {
        return nil;
    }

    return (__bridge_transfer NSString*)CFURLCopyPath((CFURLRef)url);
}

/**
 * Generates matcher that compares a URL component (scheme/host/path) with a supplied regex
 */
- (UAWhitelistMatcher)matcherForURLComponent:(NSString *)componentKey withRegexString:(NSString *)regexString {

    if (![regexString hasPrefix:@"^"]) {
        regexString = [@"^" stringByAppendingString:regexString];
    }
    if (![regexString hasSuffix:@"$"]) {
        regexString = [regexString stringByAppendingString:@"$"];
    }

    return ^BOOL(NSURL *url){
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString
                                                                               options:0
                                                                                 error:nil];
        // NSRegularExpression chokes on nil input strings, so in that case convert it into an empty string
        NSString *component;

        // The NSURL path property silently strips trailing slashes
        if ([componentKey isEqualToString:@"path"]) {
            component = [self cfPathForURL:url];
        } else {
            component = [url valueForKey:componentKey];
        }

        component = component ?: @"";

        NSRange matchRange = [regex rangeOfFirstMatchInString:component options:0 range:NSMakeRange(0, component.length)];
        return matchRange.location != NSNotFound;
    };
}

- (UAWhitelistMatcher)schemeMatcherForPattern:(NSString *)pattern {

    NSURL *url = [NSURL URLWithString:pattern];

    if (!url) {
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *scheme = url.scheme;

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

- (UAWhitelistMatcher)hostMatcherForPattern:(NSString *)pattern {
    NSURL *url = [NSURL URLWithString:pattern];

    if (!url){
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *host = url.host;

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

- (UAWhitelistMatcher)pathMatcherForPattern:(NSString *)pattern {
    NSURL *url = [NSURL URLWithString:pattern];

    if (!url) {
        UA_LERR(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    // The NSURL path property silently strips trailing slashes
    NSString *path = [self cfPathForURL:url];

    NSString *pathRegexString;

    if (!path || !path.length || [path isEqualToString:@"/*"]) {
        pathRegexString = @".*";
    } else {
        pathRegexString = [self escapeRegexString:path escapingWildcards:NO];
    }

    return [self matcherForURLComponent:@"path" withRegexString:pathRegexString];
}

- (UAWhitelistMatcher)wildcardMatcher {
    return ^BOOL(NSURL *url) {
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

- (BOOL)addEntry:(NSString *)patternString scope:(UAWhitelistScope)scope {

    if (!patternString || ![self validatePattern:patternString]) {
        UA_LERR(@"Invalid whitelist pattern: %@", patternString);
        return NO;
    }

    // NSURL won't parse strings with an actual asterisk for the scheme
    patternString = [self escapeSchemeWildcard:patternString];

    // If we have just a wildcard, match anything
    if ([patternString isEqualToString:@"*"]) {
        [self.entries addObject:[UAWhitelistEntry entryWithMatcher:[self wildcardMatcher] scope:scope]];
        return YES;
    }

    // Build matchers for each relevant component (scheme/host/path) of the URL based on the pattern string
    UAWhitelistMatcher schemeMatcher = [self schemeMatcherForPattern:patternString];
    UAWhitelistMatcher hostMatcher = [self hostMatcherForPattern:patternString];
    UAWhitelistMatcher pathMatcher = [self pathMatcherForPattern:patternString];

    // If any of these are nil, something went wrong
    if (!schemeMatcher || !hostMatcher || !pathMatcher) {
        UA_LERR(@"Unable to build pattern matchers for whitelist entry: %@", patternString);
        return NO;
    }

    // The matcher that is stored in the whitelist encompasses matching each component.
    // A URL matches if an only if all components match.
    UAWhitelistMatcher patternMatcher = ^BOOL(NSURL *url) {
        BOOL matchedScheme = schemeMatcher(url);
        BOOL matchedHost = hostMatcher(url);
        BOOL matchedPath = pathMatcher(url);
        return matchedScheme && matchedHost && matchedPath;
    };

    [self.entries addObject:[UAWhitelistEntry entryWithMatcher:[patternMatcher copy] scope:scope]];

    return YES;
}

- (BOOL)addEntry:(NSString *)patternString {
    return [self addEntry:patternString scope:UAWhitelistScopeAll];
}

- (BOOL)isWhitelisted:(NSURL *)url scope:(UAWhitelistScope)scope {
    BOOL match = NO;
    
    if (scope == UAWhitelistScopeOpenURL && !self.isOpenURLWhitelistingEnabled) {
        match = YES;
    } else {
        NSUInteger matchedScope = 0;
        
        for (UAWhitelistEntry *entry in self.entries) {
            if (entry.matcher(url)) {
                matchedScope |= entry.scope;
            }
        }
        
        match = (((UAWhitelistScope)matchedScope & scope) == scope);
    }
    
    // if the url is whitelisted, allow the delegate to reject the whitelisting
    if (match) {
        id<UAWhitelistDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(acceptWhitelisting:scope:)]) {
            match = [delegate acceptWhitelisting:url scope:scope];
        }
    }
    
    return match;
}

- (BOOL)isWhitelisted:(NSURL *)url {
    return [self isWhitelisted:url scope:UAWhitelistScopeAll];
}

@end
