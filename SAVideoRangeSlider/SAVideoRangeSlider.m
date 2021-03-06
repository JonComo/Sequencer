//
//  SAVideoRangeSlider.m
//
// This code is distributed under the terms and conditions of the MIT license.
//
// Copyright (c) 2013 Andrei Solovjev - http://solovjev.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SAVideoRangeSlider.h"

#import "SRClip.h"

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) UIView *bgView;
@property (nonatomic, strong) UIView *centerView;
@property (nonatomic, strong) NSURL *videoUrl;

@property (nonatomic, strong) SASliderLeft *leftThumb;
@property (nonatomic, strong) SASliderRight *rightThumb;
@property (nonatomic) CGFloat frame_width;
@property (nonatomic) Float64 durationSeconds;
@property (nonatomic, strong) SAResizibleBubble *popoverBubble;

@end

@implementation SAVideoRangeSlider

#define SLIDER_BORDERS_SIZE 2.0f
#define BG_VIEW_BORDERS_SIZE 0.0f

- (id)initWithFrame:(CGRect)frame clip:(SRClip *)clip
{
    if (self = [super initWithFrame:frame]) {
        //init
        
        _frame_width = frame.size.width;
        _clip = clip;
        _videoUrl = clip.URL;
        
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:clip.URL options:nil];
        
        _durationSeconds = CMTimeGetSeconds(asset.duration);
        
        _range = CMTimeRangeMake(kCMTimeZero, asset.duration);
        
        int thumbWidth = ceil(frame.size.width*0.05);
        
        _bgView = [[UIView alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor blackColor].CGColor;
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        _bgView.clipsToBounds = YES;
        [self addSubview:_bgView];
        
        _topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, SLIDER_BORDERS_SIZE)];
        _topBorder.backgroundColor = [UIColor whiteColor];
        [self addSubview:_topBorder];
        
        _bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height-SLIDER_BORDERS_SIZE, frame.size.width, SLIDER_BORDERS_SIZE)];
        _bottomBorder.backgroundColor = [UIColor whiteColor];
        [self addSubview:_bottomBorder];
        
        _leftThumb = [[SASliderLeft alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        _leftThumb.contentMode = UIViewContentModeLeft;
        _leftThumb.userInteractionEnabled = YES;
        _leftThumb.clipsToBounds = YES;
        _leftThumb.backgroundColor = [UIColor whiteColor];
        _leftThumb.layer.borderWidth = 0;
        [self addSubview:_leftThumb];
        
        
        UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftPan:)];
        [_leftThumb addGestureRecognizer:leftPan];
        
        
        _rightThumb = [[SASliderRight alloc] initWithFrame:CGRectMake(0, 0, thumbWidth, frame.size.height)];
        
        _rightThumb.contentMode = UIViewContentModeRight;
        _rightThumb.userInteractionEnabled = YES;
        _rightThumb.clipsToBounds = YES;
        _rightThumb.backgroundColor = [UIColor whiteColor];
        [self addSubview:_rightThumb];
        
        UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightPan:)];
        [_rightThumb addGestureRecognizer:rightPan];
        
        _rightPosition = frame.size.width;
        _leftPosition = 0;
        
        _centerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        _centerView.backgroundColor = [UIColor clearColor];
        [self addSubview:_centerView];
        
        UIPanGestureRecognizer *centerPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleCenterPan:)];
        [_centerView addGestureRecognizer:centerPan];
        
        
        _popoverBubble = [[SAResizibleBubble alloc] initWithFrame:CGRectMake(0, -50, 100, 50)];
        _popoverBubble.alpha = 0;
        _popoverBubble.backgroundColor = [UIColor whiteColor];
        _popoverBubble.clipsToBounds = YES;
        [self addSubview:_popoverBubble];
        
        
        _bubleText = [[UILabel alloc] initWithFrame:_popoverBubble.frame];
        _bubleText.font = [UIFont boldSystemFontOfSize:14];
        _bubleText.backgroundColor = [UIColor clearColor];
        _bubleText.textColor = [UIColor blackColor];
        _bubleText.textAlignment = NSTextAlignmentCenter;
        
        [_popoverBubble addSubview:_bubleText];
        
        [self generateThumbnails];
    }
    
    return self;
}

-(void)setPopoverBubbleSize: (CGFloat) width height:(CGFloat)height{
    
    CGRect currentFrame = _popoverBubble.frame;
    currentFrame.size.width = width;
    currentFrame.size.height = height;
    currentFrame.origin.y = -height;
    _popoverBubble.frame = currentFrame;
    
    currentFrame.origin.x = 0;
    currentFrame.origin.y = 0;
    _bubleText.frame = currentFrame;
    
}

-(void)setMaxGap:(NSInteger)maxGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*maxGap/_durationSeconds;
    _maxGap = maxGap;
}

-(void)setMinGap:(NSInteger)minGap{
    _leftPosition = 0;
    _rightPosition = _frame_width*minGap/_durationSeconds;
    _minGap = minGap;
}

- (void)delegateNotification
{
    [self updateRange];
    
    if ([_delegate respondsToSelector:@selector(videoRange:didChangeLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didChangeLeftPosition:self.leftPosition rightPosition:self.rightPosition];
    }
}

-(void)updateRange
{
    _range = CMTimeRangeMake(CMTimeMake(self.leftPosition * 1000, 1000), CMTimeMake((self.rightPosition - self.leftPosition) * 1000, 1000));
}

#pragma mark - Gestures

- (void)handleLeftPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        if (_leftPosition < 0) {
            _leftPosition = 0;
        }
        
        if (
            (_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))
            ){
            _leftPosition -= translation.x;
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        [self delegateNotification];
        
        if ([self.delegate respondsToSelector:@selector(videoRange:didPanToTime:)]){
            [self.delegate videoRange:self didPanToTime:CMTimeMake(self.leftPosition * 100000, 100000)];
        }
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
}

- (void)handleRightPan:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        
        CGPoint translation = [gesture translationInView:self];
        _rightPosition += translation.x;
        if (_rightPosition < 0) {
            _rightPosition = 0;
        }
        
        if (_rightPosition > _frame_width){
            _rightPosition = _frame_width;
        }
        
        if (_rightPosition-_leftPosition <= 0){
            _rightPosition -= translation.x;
        }
        
        if ((_rightPosition-_leftPosition <= _leftThumb.frame.size.width+_rightThumb.frame.size.width) ||
            ((self.maxGap > 0) && (self.rightPosition-self.leftPosition > self.maxGap)) ||
            ((self.minGap > 0) && (self.rightPosition-self.leftPosition < self.minGap))){
            _rightPosition -= translation.x;
        }
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        [self delegateNotification];
        
        if ([self.delegate respondsToSelector:@selector(videoRange:didPanToTime:)]){
            [self.delegate videoRange:self didPanToTime:CMTimeMake(self.rightPosition * 100000, 100000)];
        }
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
}

- (void)handleCenterPan:(UIPanGestureRecognizer *)gesture
{
    
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [gesture translationInView:self];
        
        _leftPosition += translation.x;
        _rightPosition += translation.x;
        
        if (_rightPosition > _frame_width || _leftPosition < 0){
            _leftPosition -= translation.x;
            _rightPosition -= translation.x;
        }
        
        
        [gesture setTranslation:CGPointZero inView:self];
        
        [self setNeedsLayout];
        
        [self delegateNotification];
        
    }
    
    _popoverBubble.alpha = 1;
    
    [self setTimeLabel];
    
    if (gesture.state == UIGestureRecognizerStateEnded){
        [self hideBubble:_popoverBubble];
    }
}

- (void)layoutSubviews
{
    CGFloat inset = _leftThumb.frame.size.width / 2;
    
    _leftThumb.center = CGPointMake(_leftPosition+inset, _leftThumb.frame.size.height/2);
    
    _rightThumb.center = CGPointMake(_rightPosition-inset, _rightThumb.frame.size.height/2);
    
    _topBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, 0, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    _bottomBorder.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _bgView.frame.size.height-SLIDER_BORDERS_SIZE, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width/2, SLIDER_BORDERS_SIZE);
    
    
    _centerView.frame = CGRectMake(_leftThumb.frame.origin.x + _leftThumb.frame.size.width, _centerView.frame.origin.y, _rightThumb.frame.origin.x - _leftThumb.frame.origin.x - _leftThumb.frame.size.width, _centerView.frame.size.height);
    
    
    CGRect frame = _popoverBubble.frame;
    frame.origin.x = _centerView.frame.origin.x+_centerView.frame.size.width/2-frame.size.width/2;
    _popoverBubble.frame = frame;
}

#pragma mark - Video

-(void)generateThumbnails
{
    __block float xOffset = 0;
    [self.clip generateThumbnailsForSize:CGSizeMake(self.frame.size.width, self.frame.size.height) completion:^(NSError *error, NSArray *thumbnails) {
        
        //lay them out
        for (UIView *view in self.bgView.subviews)
            [view removeFromSuperview];
        
        for (UIImage *thumb in thumbnails)
        {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:thumb];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.frame = CGRectMake(xOffset, 0, self.frame.size.height, self.frame.size.height);
            [self.bgView addSubview:imageView];
            
            xOffset += self.frame.size.height;
        }
    }];
}

#pragma mark - Properties

- (CGFloat)leftPosition
{
    return _leftPosition * _durationSeconds / _frame_width;
}

- (CGFloat)rightPosition
{
    return _rightPosition * _durationSeconds / _frame_width;
}

#pragma mark - Bubble

- (void)hideBubble:(UIView *)popover
{
    [UIView animateWithDuration:0.4
                          delay:0
                        options:UIViewAnimationCurveEaseIn | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         _popoverBubble.alpha = 0;
                     }
                     completion:nil];
    
    if ([_delegate respondsToSelector:@selector(videoRange:didGestureStateEndedLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didGestureStateEndedLeftPosition:self.leftPosition rightPosition:self.rightPosition];
    }
}

-(void) setTimeLabel{
    self.bubleText.text = [NSString stringWithFormat:@"%.2f s", self.rightPosition - self.leftPosition];
}

-(NSString *)trimDurationStr{
    int delta = floor(self.rightPosition - self.leftPosition);
    return [NSString stringWithFormat:@"%d", delta];
}

#pragma mark - Helpers

-(BOOL)isRetina{
    return ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] &&
            ([UIScreen mainScreen].scale == 2.0));
}

#pragma Export

-(void)exportVideoToURL:(NSURL *)URL completion:(void(^)(BOOL success))block
{
    AVAsset *anAsset = [[AVURLAsset alloc] initWithURL:self.videoUrl options:nil];
        
    AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]
                              initWithAsset:anAsset presetName:AVAssetExportPresetPassthrough];
    
    exportSession.outputURL = URL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    
    CMTime start = CMTimeMakeWithSeconds([self leftPosition], anAsset.duration.timescale);
    CMTime duration = CMTimeMakeWithSeconds([self rightPosition] - [self leftPosition], anAsset.duration.timescale);
    CMTimeRange range = CMTimeRangeMake(start, duration);
    
    exportSession.timeRange = range;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
        switch ([exportSession status]) {
            case AVAssetExportSessionStatusFailed:
            {
                NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(YES);
                });
            }
                break;
            case AVAssetExportSessionStatusCancelled:
            {
                NSLog(@"Export canceled");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(NO);
                });
            }
                break;
            default:
                NSLog(@"Export successful");
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (block) block(YES);
                });
                
                break;
        }
    }];
}

@end
