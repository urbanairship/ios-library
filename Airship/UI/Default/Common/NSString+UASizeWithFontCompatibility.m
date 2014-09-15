
#import "NSString+UASizeWithFontCompatibility.h"

@implementation NSString (UASizeWithFontCompatibility)


- (CGSize)uaSizeWithFont:(UIFont *)font
        constrainedToSize:(CGSize)size
            lineBreakMode:(NSLineBreakMode)lineBreakMode {

#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_7_0)

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = lineBreakMode;

    CGRect boundingRect = [self boundingRectWithSize:size
                                              options:NSStringDrawingUsesLineFragmentOrigin
                                           attributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraphStyle}
                                              context:nil];

    //the bounding rect may contain fractional width/height values
    return CGSizeMake(ceil(boundingRect.size.width), ceil(boundingRect.size.height));
#else

    return [self sizeWithFont:font constrainedToSize:size lineBreakMode:lineBreakMode];

#endif

}

@end
