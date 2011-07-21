/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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

#import "UASubscriptionUIUtil.h"

#import "UAGlobal.h"

@implementation UASubscriptionUIUtil

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

+ (NSString *)localizedAutorenewableDuration:(UAAutorenewableDuration)duration {
    NSString *arDurationString = nil;
    switch (duration) {
        case UAAutorenewableDuration7Days:
            arDurationString = @"7 Days";
            break;
        case UAAutorenewableDuration1Month:
            arDurationString = @"1 Month";
            break;
        case UAAutorenewableDuration2Months:
            arDurationString = @"2 Months";
            break;
        case UAAutorenewableDuration3Months:
            arDurationString = @"3 Months";
            break;
        case UAAutorenewableDuration6Months:
            arDurationString = @"6 Months";
            break;
        case UAAutorenewableDuration1Year:
            arDurationString = @"1 Year";
            break;
        case UAAutorenewableDurationNone:
        default:
            break;
    }
    return arDurationString;
}

@end
