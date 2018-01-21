/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageMediaView+Internal.h"
#import "UAirship.h"
#import "UAWebView+Internal.h"
#import "AVFoundation/AVFoundation.h"
#import "UAUtils.h"
#import "UAInAppMessageUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN

CGFloat const DefaultVideoHeightPadding = 60;
CGFloat const DefaultVideoAspectRatio = 16.0/9.0;

@interface UAInAppMessageMediaView()
@property (nonatomic, strong, nullable) UIImageView *imageView;
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
    self = [super init];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;

        self.webView = nil;

        self.imageView = [[UIImageView alloc] initWithFrame:self.frame];
        [self addSubview:self.imageView];
        [self.imageView setImage:image];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self containedView:self.imageView];
    }

    return self;
}

- (instancetype)initWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    self = [super init];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.mediaInfo = mediaInfo;

        self.imageView = nil;

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

        self.webView = [[WKWebView alloc] initWithFrame:self.frame configuration:config];
        [self addSubview:self.webView];
        [UAInAppMessageUtils applyContainerConstraintsToContainer:self containedView:self.webView];
    }

    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];

    if (!self.superview) {
        return;
    }
    CGFloat aspectRatio = DefaultVideoAspectRatio;
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
            [self.webView.scrollView setScrollEnabled:NO];
            NSString *urlString = [NSString stringWithFormat:@"%@%@", self.mediaInfo.url, @"?playsinline=1"];
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
            [self.webView loadRequest:request];
            break;
        }
        case UAInAppMessageMediaInfoTypeImage: {
            if (self.imageView.image.size.height != 0) {
                aspectRatio = self.imageView.image.size.width/self.imageView.image.size.height;
            }
            break;
        }
    }

    self.aspectConstraint = [NSLayoutConstraint constraintWithItem:self
                                                         attribute:NSLayoutAttributeWidth
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self
                                                         attribute:NSLayoutAttributeHeight
                                                        multiplier:aspectRatio
                                                          constant:0];

    self.widthConstraint = [NSLayoutConstraint constraintWithItem:self
                                                        attribute:NSLayoutAttributeWidth
                                                        relatedBy:NSLayoutRelationLessThanOrEqual
                                                           toItem:self.superview
                                                        attribute:NSLayoutAttributeWidth
                                                       multiplier:1
                                                         constant:0];
    self.aspectConstraint.active = YES;
    self.widthConstraint.active = YES;
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

    // Tall media can potentially break this we need it to be non-required
    self.heightConstraint.priority = 250;
    self.heightConstraint.active = YES;
}

@end

NS_ASSUME_NONNULL_END
