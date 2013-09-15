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

@interface SAVideoRangeSlider ()

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
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

- (id)initWithFrame:(CGRect)frame videoUrl:(NSURL *)videoUrl
{
    self = [super initWithFrame:frame];
    if (self) {
        
        _frame_width = frame.size.width;
        
        int thumbWidth = ceil(frame.size.width*0.05);
        
        _bgView = [[UIControl alloc] initWithFrame:CGRectMake(thumbWidth-BG_VIEW_BORDERS_SIZE, 0, frame.size.width-(thumbWidth*2)+BG_VIEW_BORDERS_SIZE*2, frame.size.height)];
        _bgView.layer.borderColor = [UIColor blackColor].CGColor;
        _bgView.layer.borderWidth = BG_VIEW_BORDERS_SIZE;
        _bgView.clipsToBounds = YES;
        [self addSubview:_bgView];
        
        _videoUrl = videoUrl;
        
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
        
        [self getMovieFrame];
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
    if ([_delegate respondsToSelector:@selector(videoRange:didChangeLeftPosition:rightPosition:)]){
        [_delegate videoRange:self didChangeLeftPosition:self.leftPosition rightPosition:self.rightPosition];
    }
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

-(void)getMovieFrame
{
    AVAsset *myAsset;
    
    if (!self.imageGenerator)
    {
        myAsset = [[AVURLAsset alloc] initWithURL:_videoUrl options:nil];
        self.imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:myAsset];
        self.imageGenerator.appliesPreferredTrackTransform = YES;
        self.imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        self.imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    }
    
    if ([self isRetina]){
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width*2, _bgView.frame.size.height*2);
    } else {
        self.imageGenerator.maximumSize = CGSizeMake(_bgView.frame.size.width, _bgView.frame.size.height);
    }
    
    int picWidth = 49;
    
    // First image
    UIImage *firstImage = [self generateThumbnailForTime:kCMTimeZero];
        
    UIImageView *tmp = [[UIImageView alloc] initWithImage:firstImage];
    [_bgView addSubview:tmp];
    picWidth = tmp.frame.size.width;

    //Generate rest of the images
    _durationSeconds = CMTimeGetSeconds([myAsset duration]);
    
    int picsCnt = ceil(_bgView.frame.size.width / picWidth);
    
    NSMutableArray *allTimes = [[NSMutableArray alloc] init];
    
    int time4Pic = 0;
    
    for (int i=1; i<picsCnt; i++){
        time4Pic = i*picWidth;
        
        CMTime timeFrame = CMTimeMakeWithSeconds(_durationSeconds*time4Pic/_bgView.frame.size.width, 600);
        
        [allTimes addObject:[NSValue valueWithCMTime:timeFrame]];
    }
    
    NSArray *times = allTimes;
    
    __block int i = 1;
    
    [self.imageGenerator generateCGImagesAsynchronouslyForTimes:times
                                              completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime,
                                                                  AVAssetImageGeneratorResult result, NSError *error) {
                                                  
                                                  if (result == AVAssetImageGeneratorSucceeded) {
                                                      
                                                      
                                                      UIImage *videoScreen;
                                                      if ([self isRetina]){
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image scale:2.0 orientation:UIImageOrientationUp];
                                                      } else {
                                                          videoScreen = [[UIImage alloc] initWithCGImage:image];
                                                      }
                                                      
                                                      
                                                      UIImageView *tmp = [[UIImageView alloc] initWithImage:videoScreen];
                                                      
                                                      CGRect currentFrame = tmp.frame;
                                                      
                                                      //int all = (i+1)*tmp.frame.size.width;
                                                      currentFrame.origin.x = i*currentFrame.size.width;
                                                      
//                                                      if (all > _bgView.frame.size.width){
//                                                          int delta = all - _bgView.frame.size.width;
//                                                          currentFrame.size.width -= delta;
//                                                      }
                                                      
                                                      tmp.frame = currentFrame;
                                                      i++;
                                                      
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [_bgView addSubview:tmp];
                                                      });
                                                  }
                                                  
                                                  if (result == AVAssetImageGeneratorFailed) {
                                                      NSLog(@"Failed with error: %@", [error localizedDescription]);
                                                  }
                                                  if (result == AVAssetImageGeneratorCancelled) {
                                                      NSLog(@"Canceled");
                                                  }
                                              }];
}

-(UIImage *)generateThumbnailForTime:(CMTime)time
{
    UIImage *videoScreen;
    
    // First image
    NSError *error;
    CMTime actualTime;
    
    CGImageRef imageRef = [self.imageGenerator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    if (imageRef != NULL) {
        if ([self isRetina]){
            videoScreen = [[UIImage alloc] initWithCGImage:imageRef scale:2.0 orientation:UIImageOrientationUp];
        } else {
            videoScreen = [[UIImage alloc] initWithCGImage:imageRef];
        }
        
        CGImageRelease(imageRef);
    }
    
    return videoScreen;
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
                NSLog(@"Export failed: %@", [[exportSession error] localizedDescription]);
                if (block) block(NO);
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Export canceled");
                if (block) block(NO);
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
