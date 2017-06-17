//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "LMPageView.h"
#import "UIScrollView+Markup.h"

@interface LMPageView () <UIScrollViewDelegate>

@end

@implementation LMPageView
{
    id<UIScrollViewDelegate> __weak _delegate;

    NSMutableArray *_pages;
    NSInteger _currentPage;

    BOOL _animating;

    NSArray *_constraints;
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

#define INIT {\
    _pages = [NSMutableArray new];\
    [super setDelegate:self]; \
    [self setPagingEnabled:YES];\
    [self setShowsHorizontalScrollIndicator:NO];\
    [self setShowsVerticalScrollIndicator:NO];\
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) INIT

    return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    if (self) INIT

    return self;
}

- (void)setDelegate:(id<UITableViewDelegate>)delegate
{
    _delegate = delegate;
}

- (NSArray *)pages
{
    return [_pages copy];
}

- (void)addPage:(UIView *)page
{
    [self insertPage:page atIndex:[_pages count]];
}

- (void)insertPage:(UIView *)page atIndex:(NSUInteger)index
{
    if ([_pages indexOfObject:page] == NSNotFound) {
        [page setTranslatesAutoresizingMaskIntoConstraints:NO];

        [self addSubview:page];

        [_pages insertObject:page atIndex:index];

        [self setNeedsUpdateConstraints];
    } else {
        [NSException raise:NSInvalidArgumentException format:@"View is already a page."];
    }
}

- (void)removePage:(UIView *)page
{
    NSUInteger index = [_pages indexOfObject:page];

    if (index != NSNotFound) {
        [_pages removeObjectAtIndex:index];

        [self setNeedsUpdateConstraints];
    }
}

- (void)willRemoveSubview:(UIView *)subview
{
    [self removePage:subview];

    [super willRemoveSubview:subview];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];

    if (![self isDragging] && !_animating) {
        [self setContentOffset:CGPointMake(_currentPage * [self bounds].size.width, [self contentOffset].y)];
    }
}

#if TARGET_OS_IOS
- (void)setCurrentPage:(NSInteger)currentPage animated:(BOOL)animated
{
    [super setCurrentPage:currentPage animated:animated];

    if (!animated) {
        _currentPage = currentPage;
    }

    _animating = animated;
}
#endif

- (void)layoutSubviews
{
    // Ensure that pages resize
    for (UIView * page in _pages) {
        [page setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [page setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        
        [page setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
        [page setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    }

    [super layoutSubviews];
}

- (void)setNeedsUpdateConstraints
{
    if (_constraints != nil) {
        [NSLayoutConstraint deactivateConstraints:_constraints];

        _constraints = nil;
    }

    if ([_pages count] == 0) {
        return;
    }

    [super setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    if (_constraints == nil) {
        if ([_pages count] > 0) {
            NSMutableArray *constraints = [NSMutableArray new];

            UIView *previousPage = nil;

            for (UIView *page in _pages) {
                // Align to siblings
                if (previousPage == nil) {
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeLeft
                        relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft
                        multiplier:1 constant:0]];
                } else {
                    [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeLeft
                        relatedBy:NSLayoutRelationEqual toItem:previousPage attribute:NSLayoutAttributeRight
                        multiplier:1 constant:0]];
                }

                // Align to parent
                [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeTop
                    relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop
                    multiplier:1 constant:0]];

                [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeBottom
                    relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom
                    multiplier:1 constant:0]];

                // Match page width/height to page view width/height
                [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeWidth
                    relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth
                    multiplier:1 constant:0]];

                [constraints addObject:[NSLayoutConstraint constraintWithItem:page attribute:NSLayoutAttributeHeight
                    relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight
                    multiplier:1 constant:0]];

                previousPage = page;
            }

            // Align final view to trailing edge
            if (previousPage != nil) {
                [constraints addObject:[NSLayoutConstraint constraintWithItem:previousPage attribute:NSLayoutAttributeRight
                    relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight
                    multiplier:1 constant:0]];
            }

            _constraints = constraints;
        }

        if (_constraints != nil) {
            [NSLayoutConstraint activateConstraints:_constraints];
        }
    }

    [super updateConstraints];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    #if TARGET_OS_IOS
    _currentPage = [self currentPage];
    #endif

    if ([_delegate respondsToSelector:@selector(scrollViewDidEndDecelerating:)]) {
        [_delegate scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    #if TARGET_OS_IOS
    _currentPage = [self currentPage];
    #endif

    _animating = NO;

    if ([_delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        [_delegate scrollViewDidEndScrollingAnimation:scrollView];
    }
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [_delegate respondsToSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if ([_delegate respondsToSelector:[invocation selector]]) {
        [invocation invokeWithTarget:_delegate];
    } else {
        [super forwardInvocation:invocation];
    }
}

- (void)appendMarkupElementView:(UIView *)view
{
    [self addPage:view];
}

@end
