/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAHTTPRequest+Internal.h"

static NSString *defaultUserAgentString;

@implementation UAHTTPRequest

+ (instancetype)requestWithURL:(NSURL *)url {
    return [[self alloc] initWithURL:url];
}

+ (instancetype)requestWithURLString:(NSString *)urlString {
    return [[self alloc] initWithURLString:urlString];
}

+ (void)setDefaultUserAgentString:(NSString *)userAgent {
    defaultUserAgentString = [userAgent copy];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        self.url = url;
        self.headers = [[NSMutableDictionary alloc] init];

        // Set Defaults
        if (defaultUserAgentString) {
            [self addRequestHeader:@"User-Agent" value:defaultUserAgentString];
        }

        self.HTTPMethod = @"GET";
    }
    return self;
}


- (instancetype)initWithURLString:(NSString *)urlString {
    return [self initWithURL:[NSURL URLWithString:urlString]];
}


- (void)addRequestHeader:(NSString *)header value:(NSString *)value {
    [self.headers setValue:value forKey:header];
}

- (void)appendBodyData:(NSData *)data {
    if (!self.body) {
        self.body = [NSMutableData data];
    }
    [self.body appendData:data];
}

- (NSString *)responseString {
    //This value should not be cached because the responseData is mutable.
    return [[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding];
}

@end

