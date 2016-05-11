/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.
 
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

//  Created by Mokhlas Hussein (iMokhles) on 08/04/16.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(NSData *data, NSInteger statusCode);
typedef void(^FailBlock)(NSError *error, NSInteger statusCode);

typedef void(^CleanBlock)();

/**
 Instead of calling:
 
 [NSURLConnection connectionWithRequest:aRequest delegate:self];
 
 You can call: 
 
 [NSURLConnection connectionWithRequest:urlRequest onCompletion:^(NSData* data)
 {
    // Success case
 } onFail:^ (NSError *error){
    // Fail case
 
 }];
 **/
@interface NSURLConnection (NSURLConnection_Blocks)

/**
 It will receive a request, a onCompletion block and a onFail block. One of them will be executed
 according to the request's response
 @param request a NSURLRequest
 @param completionBlock Block executed on success
 @param failBlock executed when the connection failed
 @return NSURLConnection* a pointer a NSURLConnection object
 */
+(NSURLConnection*)connectionWithRequest:(NSURLRequest*)request onCompletion:(CompletionBlock)completionBlock onFail:(FailBlock)failBlock;

@end
