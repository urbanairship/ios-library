
#import "UAContentURLCache.h"

@interface UAContentURLCache()

- (void)readFromDisk;
- (void)saveToDisk;

@end

@implementation UAContentURLCache

@synthesize contentDictionary;
@synthesize timestampDictionary;
@synthesize path;
@synthesize expirationInterval;

+ (UAContentURLCache *)cacheWithExpirationInterval:(NSTimeInterval)interval withPath:(NSString *)pathString {
    return [[[UAContentURLCache alloc] initWithExpirationInterval:interval withPath:pathString] autorelease];
}

- (id)initWithExpirationInterval:(NSTimeInterval)interval withPath:(NSString *)pathString{
    if (self = [super init]) {
        self.contentDictionary = [NSMutableDictionary dictionary];
        self.timestampDictionary = [NSMutableDictionary dictionary];
        self.path = pathString;
        self.expirationInterval = interval;
        
        [self readFromDisk];
    }
    
    return self;
}

- (void)saveToDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionary];
    [serialized setObject:contentDictionary forKey:@"content"];
    [serialized setObject:timestampDictionary forKey:@"timestamps"];
    [serialized writeToFile:nil atomically:YES];
}

- (void)readFromDisk {
    NSMutableDictionary *serialized = [NSMutableDictionary dictionaryWithContentsOfFile:nil];
    [contentDictionary addEntriesFromDictionary:[serialized objectForKey:@"content"]];
    [timestampDictionary addEntriesFromDictionary:[serialized objectForKey:@"timestamps"]];
}

- (void)setContent:(NSURL *)contentURL forProductURL:(NSURL *)productURL {
    NSString *contentURLString = [contentURL absoluteString];
    NSString *productURLString = [productURL absoluteString];
    [contentDictionary setObject:contentURLString forKey:productURLString];
    [timestampDictionary setObject:[NSNumber numberWithDouble:
                                   [[NSDate date]timeIntervalSince1970]]
                           forKey:productURLString];
    [self saveToDisk];
}

- (NSURL *)contentForProductURL:(NSURL *)productURL {
    NSString *productURLString = [productURL absoluteString];
    NSString *contentURLString = [contentDictionary objectForKey:productURLString];
    
    NSURL *content = [NSURL URLWithString:contentURLString];
    
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
    self.path = nil;
    [super dealloc];
}


@end
