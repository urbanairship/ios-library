
#import "UAContentURLCache.h"

@implementation UAContentURLCache

@synthesize contentDictionary;
@synthesize timestampDictionary;
@synthesize expirationInterval;

+ (UAContentURLCache *)cacheWithExpirationInterval:(NSTimeInterval)interval {
    return [[[UAContentURLCache alloc] initWithExpirationInterval:interval] autorelease];
}

- (id)initWithExpirationInterval:(NSTimeInterval)interval {
    if (self = [super init]) {
        self.contentDictionary = [NSMutableDictionary dictionary];
        self.timestampDictionary = [NSMutableDictionary dictionary];
        self.expirationInterval = interval;
    }
    
    return self;
}

- (void)setContent:(NSURL *)contentURL forProductURL:(NSURL *)productURL {
    NSString *productURLString = [NSString stringWithContentsOfURL:productURL encoding:NSUTF8StringEncoding error:NULL];
    [contentDictionary setObject:contentURL forKey:productURLString];
    [timestampDictionary setObject:[NSNumber numberWithDouble:
                                   [[NSDate date]timeIntervalSince1970]] 
                           forKey:productURLString];
}

- (NSURL *)contentForProductURL:(NSURL *)productURL {
    NSString *productURLString = [NSString stringWithContentsOfURL:productURL encoding:NSUTF8StringEncoding error:NULL];
    NSURL *content = [contentDictionary objectForKey:productURLString];
    
    if (content) {
        NSNumber *num = [timestampDictionary objectForKey:productURLString];
        if (num) {
            NSTimeInterval timestamp = [num doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (now - timestamp < expirationInterval) {
                return content;
            } else {
                [contentDictionary removeObjectForKey:productURLString];
                [timestampDictionary removeObjectForKey:productURLString];
            }
        }
    }
    
    return nil;
}

- (void)dealloc {
    self.contentDictionary = nil;
    self.timestampDictionary = nil;
    [super dealloc];
}


@end
