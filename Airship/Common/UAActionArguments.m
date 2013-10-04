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

#import "UAActionArguments.h"

@implementation UAActionArguments


NSString * const UASituationLaunchedFromPush = @"com.urbanairship.situation.launched_from_push";
NSString * const UASituationForegroundPush = @"com.urbanairship.situation.foreground_push";
NSString * const UASituationBackgroundPush = @"com.urbanairship.situation.background_push";
NSString * const UASituationLaunchedFromSpringBoard = @"com.urbanairship.situation.launched_from_springboard";
NSString * const UASituationRichPushAction = @"com.urbanairship.situation.rich_push";

- (instancetype)initWithValue:(id)value withSituation:(NSString *)situation {

    self = [super init];
    if (self) {
        self.situation = situation;
        self.value = value;
    }

    return self;
}

+ (instancetype)argumentsWithValue:(id)value withSituation:(NSString *)situation {
    return [[UAActionArguments alloc] initWithValue:value withSituation:situation];
}

+ (NSDictionary *)pendingSpringBoardPushActionArguments {
    NSMutableDictionary *arguments = [NSMutableDictionary dictionary];
    NSDictionary *pendingArguments = [[NSUserDefaults standardUserDefaults] objectForKey:kPendingPushActionDefaultsKey];

    for (NSString *name in pendingArguments) {
        NSString *value = [pendingArguments valueForKey:name];
        UAActionArguments *actionArgs = [UAActionArguments argumentsWithValue:value withSituation:UASituationLaunchedFromSpringBoard];
        [arguments setValue:actionArgs forKey:name];
    }

    return arguments;
}

+ (void)addPendingSpringBoardAction:(NSString *)name value:(NSString *)value {
    NSMutableDictionary *arguments = [NSMutableDictionary dictionary];

    NSDictionary *pendingArguments = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kPendingPushActionDefaultsKey];
    if (pendingArguments) {
        [arguments addEntriesFromDictionary:pendingArguments];
    }

    [arguments setValue:value forKey:name];
    [[NSUserDefaults standardUserDefaults] setObject:arguments forKey:kPendingPushActionDefaultsKey];
}

+ (void)removePendingSpringBoardAction:(NSString *)name {
    [self addPendingSpringBoardAction:name value:nil];
}

+ (void)clearSpringBoardActionArguments {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPendingPushActionDefaultsKey];
}
@end
