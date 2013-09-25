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
#import <Foundation/Foundation.h>

/**
 * Represents the context surrounding an action at the moment of execution.
 */
@interface UAPushActionArguments : NSObject

/**
 * Convenience constructor for UAActionArguments.
 *
 * @param name The name.
 * @param state The application state.
 * @param value The value.
 * @param extras The payload.
 */
+ (instancetype)argumentsWithName:(NSString *)name
             withApplicationState:(UIApplicationState)state
                        withValue:(id)value
                       withPayload:(NSDictionary *)payload;

/**
 * The name under which the action is registered.
 */
@property(nonatomic, copy) NSString *name;

/**
 * State of the application when the push notification was received.
 */
@property(nonatomic, assign) UIApplicationState applicationState;

/**
 * The value associated with the action in the push payload.
 * This can be an NSString or NSDictionary value.
 */
@property(nonatomic, strong) id value;

/**
 * The full push payload.
 */
@property(nonatomic, strong) NSDictionary *payload;

@end
