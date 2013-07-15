/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

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

+ (UAHTTPRequest *)requestWithURL:(NSURL *)url {
    return [[[UAHTTPRequest alloc] initWithURL:url] autorelease];
}

+ (UAHTTPRequest *)requestWithURLString:(NSString *)urlString {
    return [[[UAHTTPRequest alloc] initWithURLString:urlString] autorelease];
}

+ (void)setDefaultUserAgentString:(NSString *)userAgent {
    [defaultUserAgentString autorelease];
    defaultUserAgentString = [userAgent copy];
}

- (id)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        self.url = url;
        self.headers = [[[NSMutableDictionary alloc] init] autorelease];

        // Set Defaults
        if (defaultUserAgentString) {
            [self addRequestHeader:@"User-Agent" value:defaultUserAgentString];
        }

        self.HTTPMethod = @"GET";
    }
    return self;
}


- (id)initWithURLString:(NSString *)urlString {
    return [self initWithURL:[NSURL URLWithString:urlString]];
}

- (void) dealloc {
    self.url = nil;
    self.HTTPMethod = nil;
    self.headers = nil;
    self.username = nil;
    self.password = nil;
    self.body = nil;
    self.userInfo = nil;
    self.responseData = nil;
    self.response = nil;
    self.error = nil;

    [super dealloc];
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
    return [[[NSString alloc] initWithData:self.responseData encoding:NSUTF8StringEncoding] autorelease];
}

@end

