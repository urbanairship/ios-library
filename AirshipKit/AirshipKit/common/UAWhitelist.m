/* Copyright 2018 Urban Airship and Contributors */

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
 * Dictionary of sets of UAWhitelistMatcher blocks per scope.
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
        NSString *component = [url valueForKey:componentKey] ?: @"";

        NSRange matchRange = [regex rangeOfFirstMatchInString:component options:0 range:NSMakeRange(0, component.length)];
        return matchRange.location != NSNotFound;
    };
}

- (UAWhitelistMatcher)schemeMatcherForPattern:(NSString *)pattern {

    NSURL *url = [NSURL URLWithString:pattern];

    if (!url) {
        UA_LDEBUG(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *scheme = url.scheme;

    NSString *schemeRegexString;

    // NSURL won't parse strings with an actual asterisk for the scheme
    if (!scheme || !scheme.length || [scheme isEqualToString:@"WILDCARD"]) {
        schemeRegexString = @"(http|https)";
    } else {
        schemeRegexString = scheme;
    }

    return [self matcherForURLComponent:@"scheme" withRegexString:schemeRegexString];
}

- (UAWhitelistMatcher)hostMatcherForPattern:(NSString *)pattern {
    NSURL *url = [NSURL URLWithString:pattern];

    if (!url){
        UA_LDEBUG(@"unable to parse URL for pattern: %@", pattern);
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
        UA_LDEBUG(@"unable to parse URL for pattern: %@", pattern);
        return nil;
    }

    NSString *path = url.path;

    NSString *pathRegexString;
    if (path && path.length) {
        pathRegexString = [self escapeRegexString:path escapingWildcards:NO];
    } else {
        pathRegexString = @".*";
    }

    return [self matcherForURLComponent:@"path" withRegexString:pathRegexString];
}

- (UAWhitelistMatcher)wildcardMatcher {
    return ^BOOL(NSURL *url) {
        return [url.scheme isEqualToString:@"http"]  ||
               [url.scheme isEqualToString:@"https"] ||
               [url.scheme isEqualToString:@"file"];
    };
}

- (BOOL)validatePattern:(NSString *)pattern {
    /**
     * Regular expression to match the scheme.
     * <scheme> := '*' | 'http' | 'https'
     */
    NSString *schemeRegexString = @"((\\*)|(http)|(https))";

    /**
     * Regular expression to match the host.
     * <host> := '*' | '*.'<any char except '/' and '*'> | <any char except '/' and '*'>
     */
    NSString *hostRegexString = @"((\\*)|(\\*\\.[^/\\*]+)|([^/\\*]+))";

    /**
     * Regular expression to match the path.
     * <path> := '/' <any chars, including *>
     */
    NSString *pathRegexString =  @"(/.*)";

    /**
     * Regular expression to match the pattern.
     * <pattern> := '*' | <scheme>://<host><path> | <scheme>://<host> | file://<path>
     */
    NSString *validPatternRegexString = [NSString stringWithFormat:@"^((\\*)|((%@://%@%@)|(%@://%@)|(file://%@)))$",
                                         schemeRegexString, hostRegexString, pathRegexString,
                                         schemeRegexString, hostRegexString, pathRegexString];

    NSRegularExpression *validPatternExpression = [NSRegularExpression regularExpressionWithPattern:validPatternRegexString
                                                                            options:NSRegularExpressionUseUnicodeWordBoundaries
                                                                              error:nil];
    NSUInteger matches = [validPatternExpression numberOfMatchesInString:pattern
                                                                      options:0
                                                                        range:NSMakeRange(0, pattern.length)];
    return matches > 0;
}

- (BOOL)addEntry:(NSString *)patternString scope:(UAWhitelistScope)scope {

    if (!patternString || ![self validatePattern:patternString]) {
        UA_LWARN(@"Invalid whitelist pattern: %@", patternString);
        return NO;
    }

    if ([patternString hasPrefix:@"*://"]) {
        // NSURL won't parse strings with an actual asterisk for the scheme
        patternString = [@"WILDCARD" stringByAppendingString:[patternString substringFromIndex:1]];
    }

    // If we have just a wildcard, we need to add a special matcher for both file and https/http
    // URLs.
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
        UA_LINFO(@"Unable to build pattern matchers for whitelist entry: %@", patternString);
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

    if (scope == UAWhitelistScopeOpenURL && !self.isOpenURLWhitelistingEnabled) {
        return YES;
    }

    NSUInteger matchedScope = 0;

    for (UAWhitelistEntry *entry in self.entries) {
        if (entry.matcher(url)) {
            matchedScope |= entry.scope;
        }
    }

    return (((UAWhitelistScope)matchedScope & scope) == scope);
}

- (BOOL)isWhitelisted:(NSURL *)url {
    return [self isWhitelisted:url scope:UAWhitelistScopeAll];
}

@end
