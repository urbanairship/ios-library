
#import <Foundation/Foundation.h>

/**
 * Model object for holding JS callback argument and option data.
 */
@interface UAWebViewCallbackData : NSObject

/**
 * Processes a custom callback URL into associated callback data.
 *
 * @param url The URL to be processed.
 * @return An instance of UAWebViewCallbackData.
 */
+ (UAWebViewCallbackData *)callbackDataForURL:(NSURL *)url;

/**
 * A name, derived from the host passed in the callback URL.
 * This is typically the name of a directive or procedure.
 */
@property(nonatomic, strong) NSString *name;

/**
 * The argument strings passed in the callback.
 */
@property(nonatomic, strong) NSArray *arguments;

/**
 * The query options passed in the callback.
 */
@property(nonatomic, strong) NSDictionary *options;

@end
