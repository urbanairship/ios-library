/* Copyright 2018 Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageHTMLStyle.h"

/**
 * HTML in-app message display adapter.
 */
@interface UAInAppMessageHTMLAdapter : NSObject <UAInAppMessageAdapterProtocol>

/**
 * HTML in-app message display style defaults plist name.
 */
extern NSString *const UAHTMLStyleFileName;

/**
 * HTML in-app message display style.
 */
@property(nonatomic, strong, nullable) UAInAppMessageHTMLStyle *style;

@end
