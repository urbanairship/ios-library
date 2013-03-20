/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>

@interface UAHTTPRequest : NSObject {

}

@property (readonly, nonatomic) NSURL *url;
@property (copy, nonatomic) NSString *HTTPMethod;
@property (readonly, nonatomic) NSDictionary *headers;
@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *password;
@property (retain, nonatomic) NSMutableData *body;
@property (assign, nonatomic) BOOL compressBody;
@property (retain, nonatomic) id userInfo;

@property (readonly, nonatomic) NSHTTPURLResponse *response;
@property (readonly, nonatomic) NSError *error;

+ (UAHTTPRequest *)requestWithURLString:(NSString *)urlString;
+ (UAHTTPRequest *)requestWithURL:(NSURL *)url;

- (id)initWithURLString:(NSString *)urlString;
- (id)initWithURL:(NSURL *)url;

- (void)addRequestHeader:(NSString *)header value:(NSString *)value;
- (void)appendBodyData:(NSData *)data;

@end

@protocol UAHTTPConnectionDelegate <NSObject>
@required
- (void)request:(UAHTTPRequest *)request
        didSucceedWithResponse:(NSHTTPURLResponse *)response
                  responseData:(NSData *)responseData;
- (void)request:(UAHTTPRequest *)request didFailWithError:(NSError *)error;
@end

@interface UAHTTPConnection : NSObject {
    
    UAHTTPRequest *_request;
    NSHTTPURLResponse *_urlResponse;
	NSMutableData *_responseData;

}
@property (assign, nonatomic) id<UAHTTPConnectionDelegate> delegate;
@property (nonatomic, retain) NSURLConnection *urlConnection;


+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest;
+ (void)setDefaultUserAgentString:(NSString *)userAgent;

- (id)initWithRequest:(UAHTTPRequest *)httpRequest;
- (BOOL)start;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end
