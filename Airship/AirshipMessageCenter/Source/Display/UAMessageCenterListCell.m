/* Copyright Airship and Contributors */

#import "UAMessageCenterListCell.h"
#import "UAInboxMessage.h"
#import "UAMessageCenterDateUtils.h"
#import "UAMessageCenterStyle.h"
#import "UAMessageCenterLocalization.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@implementation UAMessageCenterListCell

- (void)setData:(UAInboxMessage *)message {
    if ([self isDateToday:message.messageSent]) {
        self.date.text = [UADateFormatter stringFromDate:message.messageSent
                                                  format:UADateFormatterFormatRelativeShort];
    } else {
        self.date.text = [UADateFormatter stringFromDate:message.messageSent
                                                  format:UADateFormatterFormatRelativeShortDate];
    }

    self.title.text = message.title;
    self.unreadIndicator.hidden = !message.unread;
    self.unreadIndicator.accessibilityHint = UAMessageCenterLocalizedString(@"ua_unread_description");


    NSString *accessibilityStringFormat;
    if (message.unread) {
        accessibilityStringFormat = UAMessageCenterLocalizedString(@"ua_message_unread_description");
    } else {
        accessibilityStringFormat = UAMessageCenterLocalizedString(@"ua_message_description");
    }

    NSString *fullDate = [UADateFormatter stringFromDate:message.messageSent
                                                  format:UADateFormatterFormatRelativeFull];
    self.accessibilityLabel = [NSString stringWithFormat:accessibilityStringFormat, message.title, fullDate];
}

- (void)setMessageCenterStyle:(UAMessageCenterStyle *)style {
    _messageCenterStyle = style;

    BOOL hidden = !style.iconsEnabled;
    self.listIconView.hidden = hidden;

    // if the icon view is hidden, set a zero width constraint to allow related views to fill its space
    if (hidden) {
        UIImageView *iconView = self.listIconView;

        NSArray *zeroWidthConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[iconView(0)]"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:NSDictionaryOfVariableBindings(iconView)];

        [self.listIconView addConstraints:zeroWidthConstraints];
    }

    self.listIconView.hidden = !style.iconsEnabled;

    if (style.cellColor) {
        self.backgroundColor = style.cellColor;
    } else if (@available(iOS 13.0, *)) {
        self.backgroundColor = [UIColor systemBackgroundColor];
    }

    if (style.cellHighlightedColor) {
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = style.cellHighlightedColor;
        self.selectedBackgroundView = bgColorView;
    }

    if (style.cellTitleFont) {
        self.title.font = [[[UIFontMetrics alloc] initForTextStyle:UIFontTextStyleBody] scaledFontForFont:style.cellTitleFont];
    }

    if (style.cellTitleColor) {
        self.title.textColor = style.cellTitleColor;
    } else if (@available(iOS 13.0, *)) {
        self.title.textColor = [UIColor labelColor];
    }

    if (style.cellTitleHighlightedColor) {
        self.title.highlightedTextColor = style.cellTitleHighlightedColor;
    }

    if (style.cellDateFont) {
        self.date.font = [[[UIFontMetrics alloc] initForTextStyle:UIFontTextStyleBody] scaledFontForFont:style.cellDateFont];
    }

    if (style.cellDateColor) {
        self.date.textColor = style.cellDateColor;
    } else if (@available(iOS 13.0, *)) {
        self.date.textColor = [UIColor labelColor];
    }

    if (style.cellDateHighlightedColor) {
        self.date.highlightedTextColor = style.cellDateHighlightedColor;
    }

    if (style.cellTintColor) {
        self.tintColor = style.cellTintColor;
    }

    // Set unread indicator background color if explicitly provided, otherwise try to apply
    // tints lowest-level first, up the view hierarchy
    if (style.unreadIndicatorColor) {
        self.unreadIndicator.backgroundColor = style.unreadIndicatorColor;
    } else if (style.cellTintColor) {
        self.unreadIndicator.backgroundColor = self.messageCenterStyle.cellTintColor;
    } else if (style.tintColor) {
        self.unreadIndicator.backgroundColor = self.messageCenterStyle.tintColor;
    }

    // needed for retina displays because the unreadIndicator is configured to rasterize in
    // UAMessageCenterListCell.xib via user-defined runtime attributes (layer.shouldRasterize)
    self.unreadIndicator.layer.rasterizationScale = [[UIScreen mainScreen] scale];
}

#if !defined(__IPHONE_14_0)
- (void)setStyle:(UAMessageCenterStyle *)style {
    [self setMessageCenterStyle:style];
}
- (UAMessageCenterStyle *)style {
    return self.messageCenterStyle;
}
#endif

// Override to prevent the default implementation from covering up the unread indicator
 - (void)setSelected:(BOOL)selected animated:(BOOL)animated {
     if (selected) {
         UIColor *defaultColor = self.unreadIndicator.backgroundColor;
         [super setSelected:selected animated:animated];
         self.unreadIndicator.backgroundColor = defaultColor;
     } else {
         [super setSelected:selected animated:animated];
     }
}

// Override to prevent the default implementation from covering up the unread indicator
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    if (highlighted) {
        UIColor *defaultColor = self.unreadIndicator.backgroundColor;
        [super setHighlighted:highlighted animated:animated];
        self.unreadIndicator.backgroundColor = defaultColor;

    } else {
        [super setHighlighted:highlighted animated:animated];
    }
}

- (BOOL)isDateToday:(NSDate *)date {
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];

    NSUInteger components = (NSCalendarUnitYear |
                             NSCalendarUnitMonth |
                             NSCalendarUnitDay);

    NSDateComponents *dateComponents = [calendar components:components fromDate:date];
    NSDateComponents *todayComponents = [calendar components:components fromDate:now];

    return (dateComponents.day == todayComponents.day &&
            dateComponents.month == todayComponents.month &&
            dateComponents.year == todayComponents.year);
}
@end

