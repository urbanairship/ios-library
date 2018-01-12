/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageMediaView+Internal.h"
#import "UAirship.h"
#import "UAWebView+Internal.h"
#import "AVFoundation/AVFoundation.h"
#import "UAUtils.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

// UAInAppMessageButtonView nib name
NSString *const UAInAppMessageMediaViewNibName = @"UAInAppMessageMediaView";
CGFloat const DefaultVideoHeightPadding = 60;
CGFloat const DefaultVideoAspectRatio = 16.0/9.0;

@interface UAInAppMessageMediaView()
@property (nonatomic, strong, nullable) IBOutlet UIImageView *imageView;
@property (nonatomic, strong, nullable) WKWebView *webView;

@property (nonatomic, strong) UAInAppMessageMediaInfo *mediaInfo;

@property (nonatomic, strong, nullable) NSLayoutConstraint *aspectConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *widthConstraint;
@property (nonatomic, strong, nullable) NSLayoutConstraint *heightConstraint;

@end

@implementation UAInAppMessageMediaView

+ (instancetype)mediaViewWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    return [[self alloc] initWithMediaInfo:mediaInfo];
}

+ (instancetype)mediaViewWithImage:(UIImage *)image {
    return [[self alloc] initWithImage:image];
}

- (instancetype)initWithImage:(UIImage *)image {
    NSBundle *bundle = [UAirship resources];

    self = [[bundle loadNibNamed:UAInAppMessageMediaViewNibName owner:self options:nil] firstObject];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.webView = nil;
        self.webView.opaque = NO;

        [self addImage:image];
    }

    return self;
}

- (instancetype)initWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    NSBundle *bundle = [UAirship resources];

    self = [[bundle loadNibNamed:UAInAppMessageMediaViewNibName owner:self options:nil] firstObject];

    if (self) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

        config.allowsInlineMediaPlayback = YES;
        config.allowsPictureInPictureMediaPlayback = YES;

        //This may work someday
        if (@available(iOS 10.0, *)) {
            config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
        } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            config.mediaPlaybackRequiresUserAction = YES;
#pragma GCC diagnostic pop
        }

        // We need to manually add a webview because WKWebView does not work in IB
        self.webView = [[WKWebView alloc] initWithFrame:self.frame configuration:config];
        [self addSubview:self.webView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self containedView:self.webView];

        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.mediaInfo = mediaInfo;
        self.imageView = nil;
        self.imageView.opaque = NO;
    }

    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];

    if (!self.superview) {
        return;
    }

    switch (self.mediaInfo.type) {
        case UAInAppMessageMediaInfoTypeVideo: {
            self.imageView = nil;
            [self.webView.scrollView setScrollEnabled:NO];
            [self.webView setBackgroundColor:[UIColor blackColor]];
            [self.webView.scrollView setBackgroundColor:[UIColor blackColor]];

            NSString *html = [NSString stringWithFormat:@"<body style=\"margin:0\"><video playsinline controls width=\"100%%\" src=\"%@\"></video></body>", self.mediaInfo.url];
            [self.webView loadHTMLString:html baseURL:[NSURL URLWithString:self.mediaInfo.url]];

            break;
        }
        case UAInAppMessageMediaInfoTypeYouTube: {
            self.imageView = nil;
            [self.webView.scrollView setScrollEnabled:NO];
            NSString *urlString = [NSString stringWithFormat:@"%@%@", self.mediaInfo.url, @"?playsinline=1"];
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            [self.webView loadRequest:request];
            break;
        }
        case UAInAppMessageMediaInfoTypeImage: {
            // Images have static size in superview
            return;
        }
    }

    self.aspectConstraint = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeWidth
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeHeight
                                                        multiplier:DefaultVideoAspectRatio
                                                          constant:0];

    self.widthConstraint = [NSLayoutConstraint constraintWithItem:self
                                                        attribute:NSLayoutAttributeWidth
                                                        relatedBy:NSLayoutRelationLessThanOrEqual
                                                           toItem:self.superview
                                                        attribute:NSLayoutAttributeWidth
                                                       multiplier:1
                                                         constant:0];
    self.aspectConstraint.priority = 250;
    self.aspectConstraint.active = YES;

    self.widthConstraint.active = YES;
    self.heightConstraint.active = YES;
}

- (void)addImage:(UIImage *)image {
    CGFloat imageAspect = image.size.width/image.size.height;
    [self.imageView setImage:image];

    if (imageAspect > 1) { // wide sizing should letterbox
        [self.imageView setBackgroundColor:[UIColor clearColor]];
        [NSLayoutConstraint constraintWithItem:self.imageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:1
                                      constant:0].active = YES;

        // Himage = (Wcontainter) * Himage/Wimage + 0
        [NSLayoutConstraint constraintWithItem:self.imageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeWidth
                                    multiplier:(1/imageAspect)
                                      constant:0].active = YES;
        //center image
        [UAInAppMessageUtils applyCenterConstraintsToContainer:self containedView:self.imageView];
    } else if (imageAspect < 1) { // tall images should letterbox
        [self setBackgroundColor:[UIColor clearColor]];
        [NSLayoutConstraint constraintWithItem:self.imageView
                                     attribute:NSLayoutAttributeHeight
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:1
                                      constant:0].active = YES;

        // Wimage = (Hcontainter) * Wimage/Himage + 0
        [NSLayoutConstraint constraintWithItem:self.imageView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:self
                                     attribute:NSLayoutAttributeHeight
                                    multiplier:imageAspect
                                      constant:0].active = YES;
        //center image
        [UAInAppMessageUtils applyCenterConstraintsToContainer:self containedView:self.imageView];
    } else { // ideal images should keep default aspect fit with no clipping
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self containedView:self.imageView];
    }
}

-(void)layoutSubviews {
    [super layoutSubviews];

    // Limit absolute height to window height - padding
    self.heightConstraint = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationLessThanOrEqual
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1
                                                          constant:[UAUtils mainWindow].frame.size.height - DefaultVideoHeightPadding];
    self.heightConstraint.active = YES;
    
}

@end

NS_ASSUME_NONNULL_END
