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

#import "UAViewUtils.h"
#import <QuartzCore/QuartzCore.h>


@implementation UAViewUtils

+ (void)roundView:(UIView*)view borderRadius:(float)radius {
    CALayer *l = [view layer];
    l.masksToBounds = YES;
    l.cornerRadius = radius;
}

+ (void)roundView:(UIView*)view borderRadius:(float)radius borderWidth:(float)border color:(UIColor*)color {
    CALayer *l = [view layer];
    l.masksToBounds = YES;
    l.cornerRadius = radius;
    l.borderWidth = border;
    l.borderColor = [color CGColor];
}

@end


#pragma mark Functions

CGAffineTransform UARotateTransformForCurrentOrientation() {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (orientation == UIDeviceOrientationLandscapeLeft) {
        return CGAffineTransformMakeRotation(M_PI*1.5);
    } else if (orientation == UIDeviceOrientationLandscapeRight) {
        return CGAffineTransformMakeRotation(M_PI/2);
    } else if (orientation == UIDeviceOrientationPortraitUpsideDown) {
        return CGAffineTransformMakeRotation(-M_PI);
    } else {
        return CGAffineTransformIdentity;
    }
}

CGRect UAFrameForCurrentOrientation(CGRect frame) {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    if (orientation == UIInterfaceOrientationLandscapeRight) {
        return CGRectMake(0, 0, frame.size.width, frame.size.height);
    } else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return CGRectMake(frame.origin.y, frame.origin.x, frame.size.width, frame.size.height);
    } else {
        return frame;
    }
}

UIViewController *UAActiveViewController() {
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow *window in windows) {
        UIResponder *responder = [window hitTest:CGPointMake(21, 21) withEvent:nil];
        while (responder) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                return (UIViewController *)responder;
            }
            responder = [responder nextResponder];
        }
    }
    return nil;
}
