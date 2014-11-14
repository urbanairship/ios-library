
#import "UAWhitelist.h"
#import "UAGlobal.h"
#import "UAConfig.h"

typedef BOOL (^UAWhitelistMatcher)(NSURL *);

@interface UAWhitelist ()
@property(nonatomic, strong) NSMutableSet *matchers;
@property(nonatomic, strong) NSRegularExpression *validPatternExpression;
@end

@implementation UAWhitelist

- (instancetype)init {
    self = [super init];
    if (self) {
        self.matchers = [NSMutableSet set];
        [self addEntry:@"https://*.urbanairship.com"];
    }
    return self;
}

+ (instancetype)whitelistWithConfig:(UAConfig *)config {
    UAWhitelist *whitelist = [[self alloc] init];

    for (NSString *entry in config.whitelist) {
        [whitelist addEntry:entry];
    }

    return whitelist;
}

- (NSString *)escapeRegexString:(NSString *)input escapingWildcards:(BOOL)escapingWildcards {

    /**
     * Regular expression characters. Used to escape any regular expression from the path and host.
     */
    NSArray *specialCharacters = @[@"\\.", @"[", @"]", @"{", @"}", @"(", @")", @"^", @"$", @"?", @"+", @"|", @"*"];

    NSString *escapedInput;
    for (NSString *character in specialCharacters) {
        escapedInput = [input stringByReplacingOccurrencesOfString:character
                                                        withString:[@"\\" stringByAppendingString:character]];
    }

    if (escapingWildcards) {
        escapedInput = [escapedInput stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
    }

    return escapedInput;
}

- (UAWhitelistMatcher)matcherForURLComponent:(NSString *)componentKey withRegexString:(NSString *)regexString {

    if (![regexString hasPrefix:@"^"]) {
        regexString = [@"^" stringByAppendingString:regexString];
    }
    if (![regexString hasSuffix:@"$"]) {
        regexString = [regexString stringByAppendingString:@"$"];
    }

    return ^BOOL(NSURL *url){
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:0 error:nil];
        NSString *component = [url valueForKey:componentKey] ?: @"";

        NSRange matchRange = [regex rangeOfFirstMatchInString:component options:0 range:NSMakeRange(0, component.length)];
        return matchRange.location != NSNotFound;
    };
}

- (UAWhitelistMatcher)schemeMatcherForPattern:(NSString *)pattern {

    NSURL *url = [NSURL URLWithString:pattern];
    NSString *scheme = url.scheme;

    NSString *schemeRegexString;

    if (!scheme || !scheme.length || [scheme isEqualToString:@"WILDCARD"]) {
        schemeRegexString = @"(http|https)";
    } else {
        schemeRegexString = scheme;
    }

    return [self matcherForURLComponent:@"scheme" withRegexString:schemeRegexString];
}

- (UAWhitelistMatcher)hostMatcherForPattern:(NSString *)pattern {
    NSURL *url = [NSURL URLWithString:pattern];
    NSString *host = url.host;

    NSString *hostRegexString;

    if (!host) {
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
     * <path> := '/' <any chars>
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
                                                                            options:0
                                                                              error:nil];
    NSUInteger matches = [validPatternExpression numberOfMatchesInString:pattern
                                                                      options:0
                                                                        range:NSMakeRange(0, pattern.length)];
    return matches > 0;
}

- (BOOL)addEntry:(NSString *)patternString {

    if (![self validatePattern:patternString]) {
        UA_LWARN(@"Invalid whitelist pattern: %@", patternString);
        return NO;
    }

    if ([patternString hasPrefix:@"*://"]) {
        patternString = [@"WILDCARD" stringByAppendingString:[patternString substringFromIndex:1]];
    }

    // If we have just a wildcard, we need to add a special matcher for both file and https/http
    // URLs.
    if ([patternString isEqualToString:@"*"]) {
        [self.matchers addObject:[self wildcardMatcher]];
        return YES;
    }

    UAWhitelistMatcher schemeMatcher = [self schemeMatcherForPattern:patternString];
    UAWhitelistMatcher hostMatcher = [self hostMatcherForPattern:patternString];
    UAWhitelistMatcher pathMatcher = [self pathMatcherForPattern:patternString];

    UAWhitelistMatcher patternMatcher = ^BOOL(NSURL *url) {
        BOOL matchedScheme = schemeMatcher(url);
        BOOL matchedHost = hostMatcher(url);
        BOOL matchedPath = pathMatcher(url);
        return matchedScheme && matchedHost && matchedPath;
    };

    [self.matchers addObject:[patternMatcher copy]];

    return true;
}

- (BOOL)isWhitelisted:(NSURL *)url {
    for (UAWhitelistMatcher matcher in self.matchers) {
        if (matcher(url)){
            return YES;
        };
    }

    return NO;
}

@end
