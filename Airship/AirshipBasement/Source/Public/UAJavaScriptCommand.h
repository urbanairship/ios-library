/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Model object for holding data associated with JS delegate calls 
 */
API_UNAVAILABLE(tvos)
NS_SWIFT_NAME(JavaScriptCommand)
@interface UAJavaScriptCommand : NSObject

///---------------------------------------------------------------------------------------
/// @name UAJavaScriptCommand Properties
///---------------------------------------------------------------------------------------

/**
 * A name, derived from the host passed in the delegate call URL.
 * This is typically the name of a command.
 */
@property (nonatomic, copy, nullable, readonly) NSString *name;

/**
 * The argument strings passed in the call.
 */
@property (nonatomic, strong, readonly) NSArray<NSString *> *arguments;

/**
 * The query options passed in the call.
 */
@property (nonatomic, strong, readonly) NSDictionary *options;

/**
 * The orignal URL that initiated the call.
 */
@property (nonatomic, strong, readonly) NSURL *URL;

///---------------------------------------------------------------------------------------
/// @name UAJavaScriptCommand Methods
///---------------------------------------------------------------------------------------

/**
 * Processes a custom delegate call URL into associated call data.
 *
 * @param URL The URL to be processed.
 * @return An instance of UAJavaScriptCommand.
 */
+ (instancetype)commandForURL:(NSURL *)URL;

- (instancetype)initWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
