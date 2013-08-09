#import "NSJSONSerialization+UAAdditions.h"

@implementation NSJSONSerialization (UAAdditions)


+ (NSString *)stringWithObject:(id)jsonObject {
    return [NSJSONSerialization stringWithObject:jsonObject options:0];
}

+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt {
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                   options:opt
                                                     error:nil];

    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

+ (id)objectWithString:(NSString *)jsonString {
    return [NSJSONSerialization JSONObjectWithData: [jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                           options: NSJSONReadingMutableContainers
                                             error: nil];
}


@end
