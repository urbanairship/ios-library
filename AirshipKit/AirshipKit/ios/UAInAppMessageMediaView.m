/* Copyright 2010-2019 Urban Airship and Contributors */

#import "UAInAppMessageMediaView+Internal.h"
#import "UAirship.h"
#import "UAWebView+Internal.h"
#import "AVFoundation/AVFoundation.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageUtils+Internal.h"
#import "UAViewUtils+Internal.h"

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

@property (nonatomic, strong) id<NSObject> modalWindowResignedKey;
@property (nonatomic, strong, nullable) id<NSObject> videoWindowResignedKey;
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

        self.mediaContainer = [[UIView alloc] init];
        self.mediaContainer.backgroundColor = [UIColor clearColor];
        self.mediaContainer.opaque = NO;
        [self addSubview:self.mediaContainer];
        [UAViewUtils applyContainerConstraintsToContainer:self containedView:self.mediaContainer];

        self.imageView = [[UIImageView alloc] initWithFrame:self.frame];
        [self.mediaContainer addSubview:self.imageView];
        [self.imageView setImage:image];
        [UAViewUtils applyContainerConstraintsToContainer:self.mediaContainer containedView:self.imageView];

        // Apply style padding
        [UAInAppMessageUtils applyPaddingToView:self.mediaContainer padding:self.style.additionalPadding replace:NO];
    }

    return self;
}

- (instancetype)initWithMediaInfo:(UAInAppMessageMediaInfo *)mediaInfo {
    self = [super init];

    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.mediaInfo = mediaInfo;

        self.imageView = nil;

        self.mediaContainer = [[UIView alloc] init];
        self.mediaContainer.backgroundColor = [UIColor clearColor];
        self.mediaContainer.opaque = NO;
        [self addSubview:self.mediaContainer];
        [UAViewUtils applyContainerConstraintsToContainer:self containedView:self.mediaContainer];

        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        config.allowsInlineMediaPlayback = YES;
        config.allowsPictureInPictureMediaPlayback = YES;

        //This may work someday
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;

        self.webView = [[WKWebView alloc] initWithFrame:self.frame configuration:config];
        [self.mediaContainer addSubview:self.webView];
        [UAViewUtils applyContainerConstraintsToContainer:self.mediaContainer containedView:self.webView];

        // Apply style padding
        [UAInAppMessageUtils applyPaddingToView:self.mediaContainer  padding:self.style.additionalPadding replace:NO];
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

            NSString *html = [NSString stringWithFormat:@"<body style=\"margin:0\"><video playsinline controls height=\"100%%\" width=\"100%%\" src=\"%@\"></video></body>", self.mediaInfo.url];
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

    self.aspectConstraint = [NSLayoutConstraint constraintWithItem:self.mediaContainer
                                                         attribute:NSLayoutAttributeWidth
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:self.mediaContainer
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

    // If the image is taller than it is wide make the width breakable
    if (aspectRatio < 1) {
        self.widthConstraint.priority = 750;
    }

    self.aspectConstraint.active = YES;
    self.widthConstraint.active = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.videoWindowResignedKey];
    [[NSNotificationCenter defaultCenter] removeObserver:self.modalWindowResignedKey];
}

-(void)layoutSubviews {
    [super layoutSubviews];

    if (self.hideWindowWhenVideoIsFullScreen) {
        if (!self.modalWindowResignedKey) {
            UA_WEAKIFY(self);
            self.modalWindowResignedKey = [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidResignKeyNotification object:self.window queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                UA_STRONGIFY(self);
                self.window.hidden = YES;
                if (self.videoWindowResignedKey) {
                    [[NSNotificationCenter defaultCenter] removeObserver:self.videoWindowResignedKey];
                }
                self.videoWindowResignedKey = [[NSNotificationCenter defaultCenter] addObserverForName:UIWindowDidResignKeyNotification object:[[UIApplication sharedApplication] keyWindow] queue:nil usingBlock:^(NSNotification * _Nonnull note) {
                    UA_STRONGIFY(self);
                    [self.window makeKeyAndVisible];
                    [[NSNotificationCenter defaultCenter] removeObserver:self.videoWindowResignedKey];
                    self.videoWindowResignedKey = nil;
                }];
            }];
        }
    }

    self.heightConstraint.active = NO;
    // Limit absolute height to window height - padding
    self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.mediaContainer
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
