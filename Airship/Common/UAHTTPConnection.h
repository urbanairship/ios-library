/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
    NSURL *url;
    NSMutableDictionary *headers;
    NSMutableData *postData;
    BOOL compressPostBody;
    id userInfo;
}
@property (readonly, nonatomic) NSURL *url;
@property (readonly, nonatomic) NSDictionary *headers;
@property (retain, nonatomic) NSData *postData;
@property (assign, nonatomic) BOOL compressPostBody;
@property (retain, nonatomic) id userInfo;

+ (UAHTTPRequest *)requestWithURLString:(NSString *)urlString;
- (id)initWithURLString:(NSString *)urlString;
- (void)addRequestHeader:(NSString *)header value:(NSString *)value;
- (void)appendPostData:(NSData *)data;

@end

@protocol UAHTTPConnectionDelegate <NSObject>
@required
- (void)requestDidSucceed:(UAHTTPRequest *)request
               response:(NSHTTPURLResponse *)response
             responseData:(NSData *)responseData;
- (void)requestDidFail:(UAHTTPRequest *)request;
@end


@interface UAHTTPConnection : NSObject {
    UAHTTPRequest *request;

    NSURLConnection *urlConnection;
    NSHTTPURLResponse *urlResponse;
	NSMutableData *responseData;

    id<UAHTTPConnectionDelegate> delegate;
}
@property (assign, nonatomic) id<UAHTTPConnectionDelegate> delegate;

+ (UAHTTPConnection *)connectionWithRequest:(UAHTTPRequest *)httpRequest;
- (id)initWithRequest:(UAHTTPRequest *)httpRequest;
- (BOOL)start;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@end
