/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

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

#import "UAKablamActionJSDelegate.h"
#import "UAActionRunner.h"

#import "UAKablamOverlayController.h"

@implementation UAKablamActionJSDelegate

- (NSString *)callbackArguments:(NSArray *)args withOptions:(NSDictionary *)options {
    UALOG(@"JS default delegate arguments: %@ \n options: %@", args, options);

    BOOL hasError = NO;
    
    NSArray *keys = [options allKeys];
    
    for (NSString *action in keys) {
        NSString *arg = [options valueForKey:action];

        if (action) {

            NSString *decodedArg = [UAKablamActionJSDelegate urlDecodedStringWithString:arg
                                                                              encoding:NSUTF8StringEncoding];
            UALOG(@"arg = %@", decodedArg);
            [UAActionRunner runActionWithName:action
                                withArguments:[UAActionArguments argumentsWithValue:decodedArg
                                                                      withSituation:UASituationRichPushAction]
                        withCompletionHandler:^(UAActionResult *finalResult) { UA_LINFO(@"Rich push action completed!");}];
        }
    }

    // do something with the args and options, set error if necessary
    // ...
    
    // invoke JS callback w/ result
    NSString *script = nil;
    if (!hasError) {
        script = @"UAListener.result = 'Callback from ObjC succeeded'; UAListener.onSuccess();";
    } else {
        script = @"UAListener.error = 'Callback from ObjC failed'; UAListener.onError();";
    }
    return script;
}

//TODO: Move this into Web View Tools / the code that delegates to this object
+ (NSString *)urlDecodedStringWithString:(NSString *)string encoding:(NSStringEncoding)encoding {
    /*
     * Taken from http://madebymany.com/blog/url-encoding-an-nsstring-on-ios
     */

    CFStringRef result = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                                                 (CFStringRef)string,
                                                                                 CFSTR(""),
                                                                                 CFStringConvertNSStringEncodingToEncoding(encoding));

    /* autoreleased string */
    NSString *value = [NSString stringWithString:(NSString *)CFBridgingRelease(result)];
    
    return value;
}

@end
