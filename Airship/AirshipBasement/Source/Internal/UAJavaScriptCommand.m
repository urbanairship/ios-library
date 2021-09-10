/* Copyright Airship and Contributors */

#import "UAJavaScriptCommand.h"

@interface UAJavaScriptCommand()
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSArray<NSString *> *arguments;
@property (nonatomic, strong, nullable) NSDictionary *options;
@property (nonatomic, strong) NSURL *URL;
@end

@implementation UAJavaScriptCommand

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
        NSString *encodedUrlPath = components.percentEncodedPath;
        if ([encodedUrlPath hasPrefix:@"/"]) {
            encodedUrlPath = [encodedUrlPath substringFromIndex:1]; //trim the leading slash
        }

        // Put the arguments into an array
        // NOTE: we special case an empty array as componentsSeparatedByString
        // returns an array with a copy of the input in the first position when passed
        // a string without any delimiters
        NSArray *arguments;
        if (encodedUrlPath.length) {
            NSArray *encodedArguments = [encodedUrlPath componentsSeparatedByString:@"/"];
            NSMutableArray *decodedArguments = [NSMutableArray arrayWithCapacity:encodedArguments.count];

            for (NSString *encodedArgument in encodedArguments) {
                [decodedArguments addObject:[encodedArgument stringByRemovingPercentEncoding]];
            }

            arguments = [decodedArguments copy];
        } else {
            arguments = [NSArray array];//empty
        }

        // Dictionary of options - primitive parsing, so external docs should mention the limitations
        NSMutableDictionary* options = [NSMutableDictionary dictionary];

        for (NSURLQueryItem *queryItem in components.queryItems) {
            NSString *key = queryItem.name;
            id value = queryItem.value ?: @"";
            if (key && value) {
                NSMutableArray *values = [options valueForKey:key];
                if (!values) {
                    values = [NSMutableArray array];
                    [options setObject:values forKey:key];
                }
                [values addObject:value];
            }
        }

        self.name = URL.host;
        self.arguments = arguments;
        self.options = options;
        self.URL = URL;
    }
    return self;
}

+ (instancetype)commandForURL:(NSURL *)URL {
    return [[self alloc] initWithURL:URL];
}

@end
