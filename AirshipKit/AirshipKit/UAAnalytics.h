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

@class UAEvent;
@class UAAssociatedIdentifiers;

NS_ASSUME_NONNULL_BEGIN

/**
 * The UAAnalytics object provides an interface to the Urban Airship Analytics API.
 */
@interface UAAnalytics : NSObject

/**
 * The conversion send ID.
 */
@property (nonatomic, copy, readonly, nullable) NSString *conversionSendID;

/**
 * The conversion push metadata.
 */
@property (nonatomic, copy, readonly, nullable) NSString *conversionPushMetadata;

/**
 * The conversion rich push ID.
 */
@property (nonatomic, copy, readonly, nullable) NSString *conversionRichPushID;

/**
 * The current session ID.
 */
@property (nonatomic, copy, readonly) NSString *sessionID;

/**
 * Date representing the last attempt to send analytics.
 * @return NSDate representing the last attempt to send analytics
 */
@property (nonatomic, strong, readonly) NSDate *lastSendTime;

/**
 * Analytics enable flag. Disabling analytics will delete any locally stored events
 * and prevent any events from uploading. Features that depend on analytics being
 * enabled may not work properly if it's disabled (reports, region triggers,
 * location segmentation, push to local time).
 *
 * Note: This property will always return `NO` if analytics is disabled in
 * UAConfig.
 */
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

/**
 * Triggers an analytics event.
 * @param event The event to be triggered
 */
- (void)addEvent:(UAEvent *)event;

/**
 * Associates identifiers with the device. This call will add a special event
 * that will be batched and sent up with our other analytics events. Previous
 * associated identifiers will be replaced.
 *
 * @param associatedIdentifiers The associated identifiers.
 */
- (void)associateDeviceIdentifiers:(UAAssociatedIdentifiers *)associatedIdentifiers;

/**
 * The device's current associated identifiers.
 * @return The device's current associated identifiers.
 */
- (UAAssociatedIdentifiers *)currentAssociatedDeviceIdentifiers;

/**
 * Initiates screen tracking for a specific app screen, must be called once per tracked screen.
 * @param screen The screen's identifier as an NSString.
 */
- (void)trackScreen:(nullable NSString *)screen;

/**
 * Schedules an event upload if one is not already scheduled.
 */
- (void)scheduleUpload;

@end

NS_ASSUME_NONNULL_END
