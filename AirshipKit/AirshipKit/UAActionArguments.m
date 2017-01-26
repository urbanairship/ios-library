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

#import "UAActionArguments.h"
#import "UAActionArguments+Internal.h"


NSString * const UAActionMetadataWebViewKey = @"com.urbanairship.webview";
NSString * const UAActionMetadataPushPayloadKey = @"com.urbanairship.payload";
NSString * const UAActionMetadataForegroundPresentationKey = @"com.urbanairship.foreground_presentation";
NSString * const UAActionMetadataInboxMessageKey = @"com.urbanairship.message";
NSString * const UAActionMetadataRegisteredName = @"com.urbanairship.registered_name";

NSString * const UAActionMetadataUserNotificationActionIDKey = @"com.urbanairship.user_notification_id";

NSString * const UAActionMetadataResponseInfoKey = @"com.urbanairship.response_info";

@implementation UAActionArguments

- (instancetype)initWithValue:(id)value
                withSituation:(UASituation)situation {

    self = [super init];
    if (self) {
        self.situation = situation;
        self.value = value;
    }

    return self;
}

- (instancetype)initWithValue:(id)value
                withSituation:(UASituation)situation
                     metadata:(NSDictionary *)metadata {
    
    self = [super init];
    if (self) {
        self.situation = situation;
        self.value = value;
        self.metadata = metadata;
    }
    
    return self;
}

+ (instancetype)argumentsWithValue:(id)value
                     withSituation:(UASituation)situation {
    return [[self alloc] initWithValue:value withSituation:situation];
}

+ (instancetype)argumentsWithValue:(id)value
                     withSituation:(UASituation)situation
                          metadata:(NSDictionary *)metadata {
    return [[self alloc] initWithValue:value withSituation:situation metadata:metadata];
}

- (NSString *)situationString {
    switch (self.situation) {
        case UASituationManualInvocation:
            return @"Manual Invocation";
            break;
        case UASituationBackgroundPush:
            return @"Background Push";
            break;
        case UASituationForegroundPush:
            return @"Foreground Push";
            break;
        case UASituationLaunchedFromPush:
            return @"Launched from Push";
            break;
        case UASituationWebViewInvocation:
            return @"Webview Invocation";
            break;
        case UASituationForegroundInteractiveButton:
            return @"Foreground Interactive Button";
            break;
        case UASituationBackgroundInteractiveButton:
            return @"Background Interactive Button";
            break;
        case UASituationAutomation:
            return @"Automation";
            break;
    }

    return @"Manual Invocation";
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAActionArguments with situation: %@, value: %@", self.situationString, self.value];
}

@end
