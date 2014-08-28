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

#import "UADeviceRegistrar.h"

@class UAChannelRegistrationPayload;
@class UADeviceAPIClient;
@class UAChannelAPIClient;


@interface UADeviceRegistrar ()


/**
 * The device API client.
 */
@property (nonatomic, strong) UADeviceAPIClient *deviceAPIClient;

/**
 * The channel API client.
 */
@property (nonatomic, strong) UAChannelAPIClient *channelAPIClient;


/**
 * The last successful payload that was registered.
 */
@property (nonatomic, strong) UAChannelRegistrationPayload *lastSuccessPayload;


/**
 * A flag indicating if the device token has been registered with the
 * device API client.
 */
@property (nonatomic, assign) BOOL isDeviceTokenRegistered;

/**
 * A flag indicating if the registrar is using the new channel registration or
 * the old device token registration.
 */
@property (nonatomic, assign) BOOL isUsingChannelRegistration;

/**
 * A flag indicating if registration is in progress.
 */
@property (atomic, assign) BOOL isRegistrationInProgress;


@end

