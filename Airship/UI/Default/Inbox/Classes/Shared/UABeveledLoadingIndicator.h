
#import <UIKit/UIKit.h>

@interface UABeveledLoadingIndicator : UIView {
    
    UIActivityIndicatorView *activity;
    
}

+ (UABeveledLoadingIndicator *)indicator;

- (void)show;
- (void)hide;

@end
