#import <Foundation/Foundation.h>

@interface NSJSONSerialization (UAAdditions)
+ (NSString *)stringWithObject:(id)jsonObject;
+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt;
+ (id)objectWithString:(NSString *)jsonString;
@end
