//
//  JCMoviePlayer.m
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "JCMoviePlayer.h"

@interface JCMoviePlayer ()
{
    AVPlayerLayer *layer;
    AVPlayerItem *playerItem;
    
    NSTimer *timerPlaying;
    
    CMTime endTime;
}

@end

@implementation JCMoviePlayer

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"dealloc player");
}

-(void)reset
{
    //refresh items
    playerItem = nil;
    
    [layer removeFromSuperlayer];
    layer.player = nil;
    layer = nil;
    
    self.player = nil;
}

-(void)setupWithPlayerItem:(AVPlayerItem *)item
{
    //[self reset];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.player = nil;
    self.player = [[AVPlayer alloc] initWithPlayerItem:item];
    
    playerItem = item;
    
    if (!layer){
        layer = [AVPlayerLayer layer];
        [self.layer addSublayer:layer];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    layer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    layer.player = self.player;
    
    self.range = CMTimeRangeMake(kCMTimeZero, playerItem.duration);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (CMTimeCompare(self.player.currentTime, self.player.currentItem.duration) == 0){
        [self stop];
    }
    
    [self play];
}

-(void)play
{
    self.isPlaying = YES;
    
    [self seekToTime:self.range.start];
    [self.player play];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
    
    timerPlaying = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(playProgress) userInfo:nil repeats:YES];
    
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
        [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateStarted];
}

-(void)pause
{
    if (!self.isPlaying) return;
    
    self.isPlaying = NO;
    
    [self.player pause];
    
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
        [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateFinished];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
}

-(void)stop
{
    [self pause];
    [self.player seekToTime:self.range.start];
}

-(void)seekToTime:(CMTime)time
{
    if (CMTIME_IS_INVALID(time)) return;
    
    NSLog(@"SEEKING: %f", CMTimeGetSeconds(time));
    
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

-(void)setRange:(CMTimeRange)range
{
    _range = range;
    
    endTime = CMTimeAdd(range.start, range.duration);
}

-(void)playProgress
{
    if (CMTimeCompare(self.player.currentTime,  endTime) == 1)
    {
        //stop it
        [self playFinished];
    }else{
        if ([self.delegate respondsToSelector:@selector(moviePlayer:playingAtTime:)])
            [self.delegate moviePlayer:self playingAtTime:self.player.currentTime];
    }
}

-(void)playFinished
{
    [timerPlaying invalidate];
    timerPlaying = nil;
    
    if (self.isPlaying)
    {
        self.isPlaying = NO;
        
        if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
            [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateFinished];
    }
}

-(void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    layer.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
}

@end
