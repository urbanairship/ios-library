/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol UACarouselDataSource, UACarouselDelegate;

/**
 * A carousel view that consists of animated image views
 */
@interface UACarousel : UIView

@property (nonatomic, weak) id<UACarouselDataSource> dataSource;
@property (nonatomic, weak) id<UACarouselDelegate> delegate;

/**
 * Scrolls the carousel by a number of items and for a selected duration
 *
 * @param itemCount Number of items to scroll by.
 * @param duration Scroll duration.
 */
- (void)scrollByNumberOfItems:(int)itemCount duration:(double)duration;

/**
 * Reloads the carousel data
 *
 */
- (void)reloadData;

@end

/**
 * Data source protocol for UACarousel.
 */
@protocol UACarouselDataSource <NSObject>

/**
 * Called to get the number of visible carousel items.
 *
 * @param carousel The current carousel.
 */
- (NSUInteger)numberOfVisibleItemsInCarousel:(UACarousel *)carousel;

/**
 * Called to get the carousel view at the corresponding index.
 *
 * @param carousel The current carousel.
 * @param index The index of the carousel view.
 * @param view The reusable view.
 */
- (UIView *)carousel:(UACarousel *)carousel viewForItemAtIndex:(NSUInteger)index reusableView:(nullable UIView *)view;

@end

/**
 * Delegate protocol for UACarousel.
 */
@protocol UACarouselDelegate <NSObject>

/**
 * Called to get the carousel item width.
 *
 * @param carousel The current carousel.
 */
- (double)itemWidthInCarousel:(UACarousel *)carousel;

/**
 * Called to get the spacing between carousel items.
 *
 * @param carousel The current carousel.
 */
- (double)spacingInCarousel:(UACarousel *)carousel;

@end

NS_ASSUME_NONNULL_END
