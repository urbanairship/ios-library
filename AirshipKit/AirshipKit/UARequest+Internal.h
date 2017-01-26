/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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
#import "UADisposable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The request builder.
 */
@interface UARequestBuilder : NSObject

/**
 * The HTTP method.
 */
@property (nonatomic, copy) NSString *method;

/**
 * The request URL.
 */
@property (nonatomic, strong) NSURL *URL;

/**
 * The user name for basic authorization.
 */
@property (nonatomic, copy, nullable) NSString *username;

/**
 * The user password for basic authorization.
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 * The request body.
 */
@property (nonatomic, copy, nullable) NSData *body;

/**
 * Flag to compress the request body using GZIP or not.
 */
@property (nonatomic, assign) BOOL compressBody;

/**
 * Sets a http request header.
 * @param value The header value.
 * @param header The header name.
 */
- (void)setValue:(id)value forHeader:(NSString *)header;

@end

/**
 * Defines a network request.
 */
@interface UARequest : NSObject

/**
 * The HTTP method.
 */
@property (nonatomic, readonly, nullable) NSString *method;

/**
 * The request URL.
 */
@property (nonatomic, readonly, nullable) NSURL *URL;

/**
 * The request headers.
 */
@property (nonatomic, readonly) NSDictionary *headers;

/**
 * The request body.
 */
@property (nonatomic, readonly, nullable) NSData *body;

/**
 * Factory method to create a request.
 * @param builderBlock A block with a request builder to customize the UARequest instance.
 * @return A UARequest instance.
 */
+ (instancetype)requestWithBuilderBlock:(void(^)(UARequestBuilder *builder))builderBlock;

@end

NS_ASSUME_NONNULL_END
