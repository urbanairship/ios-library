
#import <Foundation/Foundation.h>

@interface NSString (UALocalization)

+ (NSString *)localizedStringWithKey:(NSString *)key
                               table:(NSString *)table
                      fallbackLocale:(NSString *)fallbackLocale;

@end
