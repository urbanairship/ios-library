/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The JavaScript environment builder that is used by the native bridge.
 */
@interface UAJavaScriptEnvironment : NSObject

///---------------------------------------------------------------------------------------
/// @name JavaScript Environment Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create the JavaScript environment with the default appKey, deviceId, channel, and named user getters already defined.
 * @return The default JavaScript environment.
 */
+ (instancetype)defaultEnvironment;

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.
 */
- (void)addStringGetter:(NSString *)methodName value:(nullable NSString *)value;

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.  A nil value will return `-1` in the JavaScript environment.
*/
- (void)addNumberGetter:(NSString *)methodName value:(nullable NSNumber *)value;

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.  
*/
- (void)addDictionaryGetter:(NSString *)methodName value:(nullable NSDictionary *)value;

/**
 * Builds the script that can be injected into a web view.
 * @return The  script.
 */
- (NSString *)build;

@end

NS_ASSUME_NONNULL_END
