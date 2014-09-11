/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
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


#define kEventAppInitSize               (NSUInteger) 450//397 w/ push id, no inbox id
#define kEventAppExitSize               (NSUInteger) 200//136 w/ only network type

#define kEventDeviceRegistrationSize    (NSUInteger) 200//153 w/ only user info
#define kEventPushReceivedSize          (NSUInteger) 200//160 w/ uuid push info

/**
 * This base class encapsulates analytics events.
 */
@interface UAEvent : NSObject

/**
 * The time the event was created.
 */
@property (nonatomic, readonly, copy) NSString *time;

/**
 * The unique event ID.
 */
@property (nonatomic, readonly, copy) NSString *eventId;

/**
 * The event's data.
 */
@property (nonatomic, readonly, strong) NSDictionary *data;

/**
 * The event's type.
 */
@property (nonatomic, readonly) NSString *eventType;

/**
 * The event's estimated size.
 */
@property (nonatomic, readonly) NSUInteger estimatedSize;

/**
 * Checks if the event is valid. Invalid events will be dropped.
 * @return YES if the event is valid.
 */
- (BOOL)isValid;





@end

