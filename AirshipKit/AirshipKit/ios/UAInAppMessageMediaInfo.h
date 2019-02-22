/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Media type.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageMediaInfoType) {
    /**
     * Image media type
     */
    UAInAppMessageMediaInfoTypeImage,
    
    /**
     * Video media type
     */
    UAInAppMessageMediaInfoTypeVideo,
    
    /**
     * YouTube video
     */
    UAInAppMessageMediaInfoTypeYouTube,
};

/**
 * Defines in-app message media content.
 */
@interface UAInAppMessageMediaInfo : NSObject

/**
 * Media URL.
 */
@property(nonatomic, readonly) NSString *url;

/**
 * Media type - image, video or YouTube video.
 */
@property(nonatomic, readonly) UAInAppMessageMediaInfoType type;

/**
 * Media description.
 */
@property(nonatomic, readonly) NSString *contentDescription;

/**
 * Creates in-app message media info with a builder block.
 *
 * @return The in-app message media info.
 */
+ (instancetype)mediaInfoWithURL:(NSString *)url
              contentDescription:(NSString *)contentDescription
                            type:(UAInAppMessageMediaInfoType)type;


@end

NS_ASSUME_NONNULL_END
