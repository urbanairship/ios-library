/* Copyright Airship and Contributors */

#import "UACarouselViewController.h"
#import "UACarousel.h"

#define UIColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]

#define kUAScreenHeight CGRectGetHeight([[UIScreen mainScreen]bounds])

static NSTimeInterval const UACarouselDefaultScrollInterval = 3.0;
static const double UACarouselScrollDuration = 0.5;
static const double UACarouselDefaultImageCornerRadius = 5.0;
static const double UACarouselDefaultViewRatio = 0.75;
static const int UACarouselNumberOfVisibleItems = 3;
static const int UACarouselDefaultContentBackgroundColor = 0xFFFFFF;
static const int UACarouselDefaultBackgroundColor = 0xF8F8F8;
static const double UACarouselDefaultSpacing = 10.0;
static const double UACarouselDefaultPadding = 10.0;
static const double UACarouselSpacingInitialRatio = 1.0;
static const double UACarouselMaximumAllowedViewRatio = 1.0;
static const double UACarouselMinimumAllowedViewRatio = 0.5;
static const double UACarouselMaximumAllowedPadding = 50.0;
static const double UACarouselMaximumAllowedSpacing = 50.0;
static const double UACarouselMaximumAllowedCornerRadius = 50.0;
static NSString * const UACarouselContentModeFill = @"fill";

static NSString * const UAAccengageNotificationIDKey = @"a4sid";
static NSString * const UAAccengageCarouselNotificationTimerKey = @"acc-timer";
static NSString * const UACarouselNotificationTimerKey = @"ua-timer";
static NSString * const UACarouselNotificationRatioKey = @"ua-ratio";
static NSString * const UACarouselNotificationContentBackgroundColorKey = @"ua-contentBgColor";
static NSString * const UACarouselNotificationBackgroundColorKey = @"ua-pushBgColor";
static NSString * const UACarouselNotificationSpacingKey = @"ua-spacing";
static NSString * const UACarouselNotificationPaddingKey = @"ua-padding";
static NSString * const UACarouselNotificationCornerRadiusKey = @"ua-cornerRadius";
static NSString * const UACarouselNotificationContentModeKey = @"ua-contentMode";

@interface UACarouselViewController() <UACarouselDelegate, UACarouselDataSource>

@property (nonatomic, strong) UACarousel *carousel;
@property (nonatomic, copy) NSArray *attachments;
@property (nonatomic, copy) NSArray *images;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) double carouselImageRatio;
@property (nonatomic, assign) CGSize adaptedSize;
@property (nonatomic, assign) double spacing;

// extras
@property (nonatomic, assign) double scrollInterval;
@property (nonatomic, strong) UIColor *contentBackgroundColor;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, assign) double cornerRadius;
@property (nonatomic, assign) double spacingRatio;
@property (nonatomic, assign) double padding;
@property (nonatomic, assign) double carouselRatio;
@property (nonatomic, assign) UIViewContentMode contentMode;

@end

@implementation UACarouselViewController

- (void)dealloc{
    
    for (UNNotificationAttachment *attachment in self.attachments) {
        [attachment.URL stopAccessingSecurityScopedResource];
    }
    
    [self.timer invalidate];
    
    self.timer = nil;
    self.carousel.delegate = nil;
    self.carousel.dataSource = nil;
    self.carousel = nil;
    self.images = nil;
    self.attachments = nil;
    [self.view removeFromSuperview];
}

- (void)setupCarouselWithNotification:(UNNotification*)notification{
    NSArray *attachments = notification.request.content.attachments;
    
    if (attachments.count == 0) {
        return;
    }
    
    // preload images
    __block NSMutableArray *images = @[].mutableCopy;
    [attachments enumerateObjectsUsingBlock:^(UNNotificationAttachment *attachment, NSUInteger index, BOOL * _Nonnull stop) {
        if ([attachment.URL startAccessingSecurityScopedResource]) {
            images[index] = [UIImage imageWithContentsOfFile:attachment.URL.path];
        }
    }];
    
    if (images.count == 0) {
        return;
    }
    
    self.images = images.copy;
    
    [self initCustomParamsFromUserInfo:notification.request.content.userInfo];
    
    UIImage *firstImage = self.images[0];
    CGSize containerSize = self.view.frame.size;
    self.carouselImageRatio = firstImage.size.height / firstImage.size.width;
    
    self.adaptedSize = [self adaptedSizeFromSize:containerSize];
    [self updateWithContentSize:CGSizeMake(CGRectGetWidth(self.view.frame),  (self.adaptedSize.height > kUAScreenHeight) ? kUAScreenHeight : (self.adaptedSize.height + self.padding * 2))];
    
    self.attachments = attachments.copy;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      
        self.carousel = [[UACarousel alloc] init];
        self.carousel.delegate = self;
        self.carousel.dataSource = self;
        self.view.backgroundColor = self.backgroundColor;
        
        [self.view addSubview:self.carousel];
        
        [self addPaddingForView:self.carousel];

        if (self.images.count > 1) {
            UA_WEAKIFY(self);
            self.timer = [NSTimer scheduledTimerWithTimeInterval:self.scrollInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
                UA_STRONGIFY(self);
                [self.carousel scrollByNumberOfItems:1 duration:UACarouselScrollDuration];
            }];
        }
    });
}

- (void)initCustomParamsFromUserInfo:(NSDictionary*)userInfo {
    id ratio = userInfo[UACarouselNotificationRatioKey];
    self.carouselRatio = [self validateCarouselRatio:ratio] ? [ratio doubleValue] : UACarouselDefaultViewRatio;
    
    id padding = userInfo[UACarouselNotificationPaddingKey];
    self.padding = [self validateCarouselPadding:padding] ? [padding doubleValue] : UACarouselDefaultPadding;
    
    id cornerRadius = userInfo[UACarouselNotificationCornerRadiusKey];
    self.cornerRadius = [self validateCarouselCornerRadius:cornerRadius] ? [cornerRadius doubleValue] : UACarouselDefaultImageCornerRadius;
    
    id contentMode = userInfo[UACarouselNotificationContentModeKey];
    self.contentMode = [self validateCarouselContentMode:contentMode] ? UIViewContentModeScaleAspectFill : UIViewContentModeScaleAspectFit;
    
    id backgroundColor = userInfo[UACarouselNotificationBackgroundColorKey];
    self.backgroundColor = [self validateCarouselBackgroundColor:backgroundColor] ? UIColorFromRGB([backgroundColor intValue]) : UIColorFromRGB(UACarouselDefaultBackgroundColor);
    
    id contentBackgroundColor = userInfo[UACarouselNotificationContentBackgroundColorKey];
    self.contentBackgroundColor = [self validateCarouselBackgroundColor:contentBackgroundColor] ? UIColorFromRGB([contentBackgroundColor intValue]) : UIColorFromRGB(UACarouselDefaultContentBackgroundColor);
    
    BOOL isAccengagePayload = NO;
    if (userInfo[UAAccengageNotificationIDKey]) {
        isAccengagePayload = YES;
    }
    
    id notificationTimer = isAccengagePayload ? userInfo[UAAccengageCarouselNotificationTimerKey] : userInfo[UACarouselNotificationTimerKey];
    self.scrollInterval = [self validateCarouselNotificationTimer:notificationTimer] ? [notificationTimer doubleValue] : UACarouselDefaultScrollInterval;
    
    id spacing = userInfo[UACarouselNotificationSpacingKey];
    self.spacing = [self validateCarouselSpacing:spacing] ? [spacing doubleValue] : UACarouselDefaultSpacing;
    self.spacingRatio = [self spacingRatioFromSpacing:self.spacing];
}

- (BOOL)validateCarouselRatio:(id)ratio {
    return [ratio isKindOfClass:[NSNumber class]] &&
           [ratio doubleValue] >= UACarouselMinimumAllowedViewRatio &&
           [ratio doubleValue] <= UACarouselMaximumAllowedViewRatio;
}

- (BOOL)validateCarouselPadding:(id)padding {
    return [padding isKindOfClass:[NSNumber class]] &&
           [padding doubleValue] >= 0.0 &&
           [padding doubleValue] <= UACarouselMaximumAllowedPadding;
}

- (BOOL)validateCarouselCornerRadius:(id)cornerRadius {
    return [cornerRadius isKindOfClass:[NSNumber class]] &&
           [cornerRadius doubleValue] >= 0.0 &&
           [cornerRadius doubleValue] <= UACarouselMaximumAllowedCornerRadius;
}

- (BOOL)validateCarouselNotificationTimer:(id)timer {
    return [timer isKindOfClass:[NSNumber class]] &&
           [timer doubleValue] >= 0.0;
}

- (BOOL)validateCarouselSpacing:(id)spacing {
    return [spacing isKindOfClass:[NSNumber class]] &&
           [spacing doubleValue] >= 0.0 &&
           [spacing doubleValue] <= UACarouselMaximumAllowedSpacing;
}

- (BOOL)validateCarouselContentMode:(id)contentMode {
    return [contentMode isKindOfClass:[NSString class]] &&
           [[contentMode lowercaseString] isEqualToString:UACarouselContentModeFill];
}

- (BOOL)validateCarouselBackgroundColor:(id)color {
    return [color isKindOfClass:[NSNumber class]];
}

- (void)addPaddingForView:(UIView*)view{
    view.translatesAutoresizingMaskIntoConstraints = NO;
    UIEdgeInsets padding = UIEdgeInsetsMake(self.padding, 0, self.padding, 0);
    UIView *superview = view.superview;
    
    [superview addConstraints:@[[NSLayoutConstraint constraintWithItem:view
                                                             attribute:NSLayoutAttributeTop
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:superview
                                                             attribute:NSLayoutAttributeTop
                                                            multiplier:1.0
                                                              constant:padding.top],
                                
                                [NSLayoutConstraint constraintWithItem:view
                                                             attribute:NSLayoutAttributeLeft
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:superview
                                                             attribute:NSLayoutAttributeLeft
                                                            multiplier:1.0
                                                              constant:padding.left],
                                
                                [NSLayoutConstraint constraintWithItem:view
                                                             attribute:NSLayoutAttributeBottom
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:superview
                                                             attribute:NSLayoutAttributeBottom
                                                            multiplier:1.0
                                                              constant:-padding.bottom],
                                
                                [NSLayoutConstraint constraintWithItem:view
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:superview
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0
                                                              constant:-padding.right]
    ]];
}

#pragma mark -
#pragma mark UACarousel methods

- (NSUInteger)numberOfVisibleItemsInCarousel:(UACarousel *)carousel {
   return (self.images.count > 1) ? UACarouselNumberOfVisibleItems : 1;
}

- (double)itemWidthInCarousel:(UACarousel *)carousel {
    return CGRectGetWidth(self.carousel.frame) * self.carouselRatio;
}

- (double)spacingInCarousel:(UACarousel *)carousel {
    return self.spacingRatio;
}

- (UIView *)carousel:(UACarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusableView:(UIView *)view {
    if (view == nil) {        
        view = (UIImageView *)[[UIImageView alloc] init];
        view.layer.masksToBounds = YES;
        view.layer.cornerRadius = self.cornerRadius;
        ((UIImageView *)view).contentMode = self.contentMode;
        
        CGRect frame = view.frame;
        frame.size = self.adaptedSize;
        view.frame = frame;
        
        view.backgroundColor = self.contentBackgroundColor;
        
        if (self.images.count == 1) {
            self.view.backgroundColor = view.backgroundColor;
        }
    }
    
    NSUInteger newIndex = index % self.images.count;
    ((UIImageView *)view).image = self.images[newIndex];
    
    return view;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
    self.spacingRatio = [self spacingRatioFromSpacing:self.spacing];
    
    if (self.carousel) {
        [self.carousel reloadData];
    }
    
    self.adaptedSize = [self adaptedSizeFromSize:size];
    [self updateWithContentSize:CGSizeMake(size.width, (self.adaptedSize.height > kUAScreenHeight) ? kUAScreenHeight : (self.adaptedSize.height + self.padding * 2))];
}

- (void)updateWithContentSize:(CGSize)size {
    self.parentViewController.preferredContentSize = size;
}

- (CGSize)adaptedSizeFromSize:(CGSize)size {
    CGFloat adaptedWidth = round(size.width * self.carouselRatio);
    CGFloat adaptedHeight = (adaptedWidth * self.carouselImageRatio);
    return CGSizeMake(adaptedWidth, (adaptedHeight > kUAScreenHeight) ? kUAScreenHeight : adaptedHeight);
}

- (double)spacingRatioFromSpacing:(double)spacing {
    return (UACarouselSpacingInitialRatio + (spacing / (CGRectGetWidth(self.view.frame) * self.carouselRatio)));
}

@end
