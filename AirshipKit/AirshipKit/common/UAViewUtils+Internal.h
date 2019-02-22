/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UAViewUtils : NSObject

/**
 * Constrains the contained view to the center of the container with equivalent size
 *
 * This method has the side effect of setting both views' translatesAutoresizingMasksIntoConstraints parameters to NO.
 * This is done to ensure that autoresizing mask constraints do not conflict with the centering constraints.
 *
 * @param container The container view.
 * @param contained The contained view.
 */
+ (void)applyContainerConstraintsToContainer:(UIView *)container containedView:(UIView *)contained;

@end
