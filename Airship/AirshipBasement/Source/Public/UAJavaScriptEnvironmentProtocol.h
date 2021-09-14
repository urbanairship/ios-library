/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


NS_SWIFT_NAME(JavaScriptEnvironmentProtocol)
@protocol UAJavaScriptEnvironmentProtocol <NSObject>

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.
 */
- (void)addStringGetter:(NSString *)methodName value:(nullable NSString *)value NS_SWIFT_NAME(add(_:string:));

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.  A nil value will return `-1` in the JavaScript environment.
*/
- (void)addNumberGetter:(NSString *)methodName value:(nullable NSNumber *)value
NS_SWIFT_NAME(add(_:number:));

/**
 * Adds a getter to the `UAirship` JavaScript instance.
 * @param methodName The getter's name.
 * @param value The getter's value.
*/
- (void)addDictionaryGetter:(NSString *)methodName value:(nullable NSDictionary *)value NS_SWIFT_NAME(add(_:dictionary:));

/**
 * Builds the script that can be injected into a web view.
 * @return The script.
 */
- (NSString *)build;
@end


NS_ASSUME_NONNULL_END
