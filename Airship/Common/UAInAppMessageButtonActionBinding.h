
#import <Foundation/Foundation.h>
#import "UAActionArguments.h"

/**
 * Model object representing a binding between an in-app
 * message button, a localized title and action name/argument pairs.
 */
@interface UAInAppMessageButtonActionBinding : NSObject

/**
 * The localized title of the button.
 */
@property(nonatomic, copy) NSString *localizedTitle;

/**
 * A dictionary mapping action names to action values, to
 * be run when the button is pressed.
 */
@property(nonatomic, copy) NSDictionary *actions;

/**
 * The action's situation.
 */
@property (nonatomic, assign) UASituation situation;

@end
