#import <Foundation/Foundation.h>

@interface NSJSONSerialization (UAirship)
+ (NSString *)stringWithObject:(id)jsonObject;
+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt;
+ (id) objectWithString:(NSString *)jsonString;
@end
