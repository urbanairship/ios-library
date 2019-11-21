/* Copyright Airship and Contributors */

#import "UACarousel.h"

@interface UACarousel ()

@property (nonatomic, strong) NSMutableDictionary *itemViews;
@property (nonatomic, strong) NSMutableSet *itemViewPool;
@property (nonatomic, assign) NSUInteger numberOfVisibleItems;
@property (nonatomic, assign) double itemWidth;
@property (nonatomic, assign) double spacing;
@property (nonatomic, assign) double startOffset;
@property (nonatomic, assign) double endOffset;
@property (nonatomic, assign) NSTimeInterval scrollDuration;
@property (nonatomic, assign, getter = isScrolling) BOOL scrolling;
@property (nonatomic, assign) double scrollOffset;
@property (nonatomic, assign) double startTime;
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation UACarousel

#pragma mark -
#pragma mark Initialisation

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.itemViews = @{}.mutableCopy;
        self.itemViewPool = [NSMutableSet set];
    }
    
    return self;
}

- (NSUInteger)numberOfVisibleItems {
    if (!_numberOfVisibleItems) {
        _numberOfVisibleItems = [_dataSource numberOfVisibleItemsInCarousel:self];
    }
    
    return _numberOfVisibleItems;
}

- (double)spacing {
    if (!_spacing) {
        _spacing = [_delegate spacingInCarousel:self];
    }
    
    return _spacing;
}

- (double)itemWidth {
    if (!_itemWidth) {
        _itemWidth = [_delegate itemWidthInCarousel:self];
    }
    
    return _itemWidth;
}

#pragma mark -
#pragma mark View management

- (UIView *)itemViewAtIndex:(NSUInteger)index {
    return self.itemViews[@(index)];
}

- (void)setItemView:(UIView *)view forIndex:(NSUInteger)index {
    self.itemViews[@(index)] = view;
}

- (void)queueItemView:(UIView *)view {
    if (view) {
        [self.itemViewPool addObject:view];
    }
}

- (UIView *)dequeueItemView {
    UIView *view = [self.itemViewPool anyObject];
    if (view) {
        [self.itemViewPool removeObject:view];
    }
    return view;
}

#pragma mark -
#pragma mark View layout

- (UIView *)containerViewFromView:(UIView *)view {
    CGRect frame = view.bounds;
    frame.size.width =  self.itemWidth;
    UIView *containerView = [[UIView alloc] initWithFrame:frame];
    
    [containerView addSubview:view];
    
    return containerView;
}

- (void)transformItemView:(UIView *)view atIndex:(NSUInteger)index {
    double offset = index - self.scrollOffset;
    
    view.center = CGPointMake(CGRectGetWidth(self.bounds)/2.0,
                              CGRectGetHeight(self.bounds)/2.0);
    
    CATransform3D transform = CATransform3DIdentity;
    transform = CATransform3DTranslate(transform, offset * self.itemWidth * self.spacing, 0.0, 0.0);
    view.layer.transform = transform;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self loadViews];
    [self.itemViews enumerateKeysAndObjectsUsingBlock:^(id index, id view, BOOL * _Nonnull stop) {
        [self transformItemView:view atIndex:[index unsignedIntValue]];
    }];
}

#pragma mark -
#pragma mark View loading

- (UIView *)loadViewAtIndex:(NSUInteger)index {
    UIView *view = [self.dataSource carousel:self viewForItemAtIndex:index reusableView:[self dequeueItemView]];
    
    if (!view) {
        view = [[UIView alloc] init];
    }
    
    [self setItemView:view forIndex:index];
    [self addSubview:[self containerViewFromView:view]];
    
    return view;
}

- (void)loadViews {
    NSMutableSet *visibleIndexes = [NSMutableSet setWithCapacity:self.numberOfVisibleItems];
    int offset = round(self.scrollOffset) - self.numberOfVisibleItems/2;
    
    for (int i = 0; i < self.numberOfVisibleItems; i++) {
        NSUInteger index = i + offset;
        [visibleIndexes addObject:@(index)];
    }
    
    for (NSNumber *index in visibleIndexes) {
        UIView *view = self.itemViews[index];
        if (!view) {
            [self loadViewAtIndex:[index unsignedIntValue]];
        }
    }
    
    NSMutableSet *allRemainingIndexes = [NSMutableSet setWithArray:[self.itemViews allKeys]];
    [allRemainingIndexes minusSet:visibleIndexes];
    
    for (NSNumber *number in allRemainingIndexes) {
        UIView *view = self.itemViews[number];
        
        [self queueItemView:view];
        [view.superview removeFromSuperview];
        [self.itemViews removeObjectForKey:number];
    }
}

- (void)reloadData {
    for (UIView *view in [self.itemViews allValues]) {
        [view removeFromSuperview];
    }
    
    id dataSource = self.dataSource;
    self.itemWidth = [dataSource itemWidthInCarousel:self];
    self.spacing = [dataSource spacingInCarousel:self];
    
    [self.itemViews removeAllObjects];
    [self.itemViewPool removeAllObjects];
}

#pragma mark -
#pragma mark Scrolling

- (void)scrollByNumberOfItems:(int)itemCount duration:(double)duration {
    double offset = (floor(self.scrollOffset) + itemCount) - self.scrollOffset;
    
    self.scrolling = YES;
    self.startTime = CACurrentMediaTime();
    self.startOffset = self.scrollOffset;
    self.scrollDuration = duration;
    self.endOffset = self.startOffset + offset;
    
    [self startAnimation];
}

#pragma mark -
#pragma mark Animation

- (void)startAnimation {
    if (!self.timer) {
        self.timer = [NSTimer timerWithTimeInterval:1.0/60.0
                                             target:self
                                           selector:@selector(animate)
                                           userInfo:nil
                                            repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];        
    }
}

- (void)stopAnimation {
    [self.timer invalidate];
    self.timer = nil;
}

- (double)easedTimeFromTime:(double)time {
    return pow(time, 2.0) * (3.0 - 2.0 * time);
}

- (void)animate {
    [CATransaction begin];
    
    NSTimeInterval currentTime = CACurrentMediaTime();
    
    if (self.scrolling) {
        NSTimeInterval time = MIN(1.0, (currentTime - self.startTime) / self.scrollDuration);
        double delta = [self easedTimeFromTime:time];
        self.scrollOffset = self.startOffset + (self.endOffset - self.startOffset) * delta;
        
        [self loadViews];
        [self.itemViews enumerateKeysAndObjectsUsingBlock:^(id index, id view, BOOL * _Nonnull stop) {
            [self transformItemView:view atIndex:[index intValue]];
        }];
        
        if (time >= 1.0) {
            self.scrolling = NO;
            [CATransaction commit];
        }
    }
    
    [CATransaction commit];
}

@end
