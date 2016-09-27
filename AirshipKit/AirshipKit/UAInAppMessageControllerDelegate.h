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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UAInAppMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for providing custom UI to the
 * UAInAppMessageController.
 */
@protocol UAInAppMessageControllerDelegate <NSObject>

@required

/**
 * Returns a view configured with data from the provided message.
 * Use this method to configure your custom view with colors, alert
 * text, etc.
 *
 * @param message The associated in-app message.
 * @param parentView The parent view the messageView will be embedded in
 * @return A configured instance of UIView.
 */
- (UIView *)viewForMessage:(UAInAppMessage *)message parentView:(UIView *)parentView;

/**
 * Returns the button corresponding to the indexed action
 * associated with the message. This button will be
 * automatically configured for touch events in the controller.
 *
 * @param messageView The custom message view.
 * @param index The index of the action.
 * @return An instance of UIControl.
 */
- (UIControl *)messageView:(UIView *)messageView buttonAtIndex:(NSUInteger)index;

@optional

/**
 * Indicates that the message view has changed touch state, meaning that the message view
 * has been tapped and touch is either down or up. Use this event to update the view accordingly, 
 * such as by inverting colors.
 *
 * @param messageView The message view.
 * @param touchDown YES if the event represents a touch down, NO if it represents a touch up.
 */
- (void)messageView:(UIView *)messageView didChangeTouchState:(BOOL)touchDown;

/**
 * Display animation hook. Use this event to perform custom animation for the message view.
 * At the time this method is called, the message view will already be added as a sub view of
 * the parent, with no positioning other than that dictated by its geometry or layout cronstraints.
 * It is the delegate's responsibility to ensure that it animates to its final display position, which
 * would typically be a transition from offscreen coordinates to its proper display coordinates.
 *
 * @param messageView The associated message view.
 * @param parentView The parent view the message view has been added to.
 * @param completionHandler A completion handler to call once the animation is complete.
 */
- (void)messageView:(UIView *)messageView animateInWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler;

/**
 * Dismiss animation hook. Use this event to perform custom animation for the message view.
 * It is the delegate's responsibility to ensure that it animates to its final dismissal position,
 * which would typically be offscreen coordinates.
 *
 * @param messageView The associated message view.
 * @param parentView The parent view the message view has been added to.
 * @param completionHandler A completion handler to call once the animation is complete.
 */
- (void)messageView:(UIView *)messageView animateOutWithParentView:(UIView *)parentView completionHandler:(void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END
