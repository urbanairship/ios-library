/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Display content for an in-app message.
 */
@interface UAInAppMessageDisplayContent : NSObject

/**
 * Display types.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageDisplayType) {
    /**
     * Banner display
     */
    UAInAppMessageDisplayTypeBanner,

    /**
     * Full screen display
     */
    UAInAppMessageDisplayTypeFullScreen,

    /**
     * Modal display
     */
    UAInAppMessageDisplayTypeModal,

    /**
     * HTML display
     */
    UAInAppMessageDisplayTypeHTML,

    /**
     * Custom display
     */
    UAInAppMessageDisplayTypeCustom
};

/**
 * Button layout.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageButtonLayoutType) {
    /**
     * Stacked button layout
     */
    UAInAppMessageButtonLayoutTypeStacked,
    
    /**
     * Separate button layout
     */
    UAInAppMessageButtonLayoutTypeSeparate,
    
    /**
     * Joined button layout
     */
    UAInAppMessageButtonLayoutTypeJoined,
};

/**
 * JSON keys and values.
 */
extern NSString *const UAInAppMessageBodyKey;
extern NSString *const UAInAppMessageHeadingKey;
extern NSString *const UAInAppMessageBackgroundColorKey;
extern NSString *const UAInAppMessagePlacementKey;
extern NSString *const UAInAppMessageContentLayoutKey;
extern NSString *const UAInAppMessageBorderRadiusKey;
extern NSString *const UAInAppMessageButtonLayoutKey;
extern NSString *const UAInAppMessageButtonsKey;
extern NSString *const UAInAppMessageMediaKey;
extern NSString *const UAInAppMessageURLKey;
extern NSString *const UAInAppMessageDismissButtonColorKey;
extern NSString *const UAInAppMessageFooterKey;
extern NSString *const UAInAppMessageDurationKey;
extern NSString *const UAInAppMessageModalAllowsFullScreenKey;
extern NSString *const UAInAppMessageHTMLAllowsFullScreenKey;


/**
 * Buttons are stacked.
 */
extern NSString *const UAInAppMessageButtonLayoutStackedValue;

/**
 * Buttons are displayed with a space between them.
 */
extern NSString *const UAInAppMessageButtonLayoutSeparateValue;

/**
 * Buttons are displayed right next to each other.
 */
extern NSString *const UAInAppMessageButtonLayoutJoinedValue;

/**
 * The display type.
 */
@property(nonatomic, readonly) UAInAppMessageDisplayType displayType;


/**
 * Method to return the display content as its JSON representation.
 * Sub-classes must override this method
 *
 * @returns JSON representation of the display content (as NSDictionary)
 */
- (NSDictionary *)toJSON;

@end

