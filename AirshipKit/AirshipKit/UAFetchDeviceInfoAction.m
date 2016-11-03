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


#import "UAFetchDeviceInfoAction.h"
#import "UAirship.h"
#import "UALocation.h"
#import "UAPush.h"
#import "UANamedUser.h"

@implementation UAFetchDeviceInfoAction

NSString *const UAChannelIDKey = @"channel_id";
NSString *const UANamedUserKey = @"named_user";
NSString *const UATagsKey = @"tags";
NSString *const UAPushOptInKey = @"push_opt_in";
NSString *const UALocationEnabledKey = @"location_enabled";

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setValue:[UAirship push].channelID forKey:UAChannelIDKey];
    [dict setValue:[UAirship namedUser].identifier forKey:UANamedUserKey];
    
    NSArray *tags = [[UAirship push] tags];
    if (tags.count) {
        [dict setValue:tags forKey:UATagsKey];
    }

    BOOL optedIn = [UAirship push].authorizedNotificationOptions != 0;
    [dict setValue:@(optedIn) forKey:UAPushOptInKey];
    
    BOOL locationEnabled = [UAirship location].locationUpdatesEnabled;
    [dict setValue:@(locationEnabled) forKey:UALocationEnabledKey];
    
    completionHandler([UAActionResult resultWithValue:dict]);
}


@end
