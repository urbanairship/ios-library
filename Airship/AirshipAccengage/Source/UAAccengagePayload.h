/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const UAAccengageButtonWebviewAction;
extern NSString * const UAAccengageButtonBrowserAction;

@interface UAAccengagePayload : NSObject

/**
 * Factory method for creating a payload from a NSDictionary.
 */
+ (instancetype)payloadWithDictionary:(NSDictionary *)dictionary;

/**
 * The Accengage push ID.
 */
@property (nonatomic, readonly) NSString *identifier;

/**
 *  The push action url.
 */
@property (nonatomic, readonly) NSString *url;

/**
 *  A flag indicating whether the action to run is an externalURLAction.
 */
@property (nonatomic, readonly, getter=hasExternalURLAction) BOOL externalURLAction;

/**
 *  An array of UAAccengageButton objects.
*/
@property (nonatomic, readonly) NSArray *buttons;

@end

@interface UAAccengageButton: NSObject

/**
 * Factory method for creating a button payload from a NSDictionary.
 */
+ (instancetype)buttonWithJSONObject:(id)object;

/**
 * The button ID.
 */
@property (nonatomic, readonly) NSString *identifier;

/**
 *  The button action url.
 */
@property (nonatomic, readonly) NSString *url;

/**
 * The button action type.
 */
@property (nonatomic, readonly) NSString *actionType;

@end

NS_ASSUME_NONNULL_END
