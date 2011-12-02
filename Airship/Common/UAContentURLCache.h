
#import <Foundation/Foundation.h>

@interface UAContentURLCache : NSObject {
    NSMutableDictionary *contentDictionary; //of product url string -> content NSURL
    NSMutableDictionary *timestampDictionary; //of product url string -> NSNumber of epoch timestamp
    NSTimeInterval expirationInterval;
}

+ (UAContentURLCache *)cacheWithExpirationInterval:(NSTimeInterval)interval;
- (id)initWithExpirationInterval:(NSTimeInterval)interval;

- (void)setContent:(NSURL *)contentURL forProductURL:(NSURL *)productURL;
- (NSURL *)contentForProductURL:(NSURL *)productURL;

@property (nonatomic, retain) NSMutableDictionary *contentDictionary;
@property (nonatomic, retain) NSMutableDictionary *timestampDictionary;
@property (nonatomic, assign) NSTimeInterval expirationInterval;

@end
