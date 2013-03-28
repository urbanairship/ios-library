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

@class UAHTTPRequest;
typedef void (^UAHTTPConnectionSuccessBlock)(UAHTTPRequest *request);
typedef void (^UAHTTPConnectionFailureBlock)(UAHTTPRequest *request);

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
@property (readonly, nonatomic) NSString *responseString;
@property (readonly, nonatomic) NSData *responseData;
@property (readonly, nonatomic) NSError *error;

+ (UAHTTPRequest *)requestWithURLString:(NSString *)urlString;
+ (UAHTTPRequest *)requestWithURL:(NSURL *)url;

- (id)initWithURLString:(NSString *)urlString;
- (id)initWithURL:(NSURL *)url;

- (void)addRequestHeader:(NSString *)header value:(NSString *)value;
- (void)appendBodyData:(NSData *)data;

@end

/**
 *
 */
@interface UAHTTPConnection : NSObject <NSURLConnectionDelegate> {

}

@property (nonatomic, retain) NSURLConnection *urlConnection;

@property (assign, nonatomic) id delegate;
@property (nonatomic, assign) SEL successSelector;
@property (nonatomic, assign) SEL failureSelector;

@property (nonatomic, copy) UAHTTPConnectionSuccessBlock successBlock;
@property (nonatomic, copy) UAHTTPConnectionFailureBlock failureBlock;


+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest;

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest
                                   delegate:(id)delegate
                                    success:(SEL)successSelector
                                    failure:(SEL)failureSelector;

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest
                               successBlock:(UAHTTPConnectionSuccessBlock)successBlock
                               failureBlock:(UAHTTPConnectionSuccessBlock)failureBlock;

+ (void)setDefaultUserAgentString:(NSString *)userAgent;

- (id)initWithRequest:(UAHTTPRequest *)httpRequest;
- (BOOL)start;

//TODO: ensure that empty PUTs have a content-length header


- (BOOL)startSynchronous;
- (void)cancel;

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end
