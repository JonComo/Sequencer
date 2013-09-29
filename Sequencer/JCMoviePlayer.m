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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
     
    //refresh items
    playerItem = nil;
    
    [layer removeFromSuperlayer];
    layer.player = nil;
    layer = nil;
    
    self.player = nil;
}

-(void)setupWithPlayerItem:(AVPlayerItem *)item
{
    [self reset];
    
    playerItem = item;
    
    self.player = [[AVPlayer alloc] initWithPlayerItem:item];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playFinished) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    layer = [AVPlayerLayer layer];
    layer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    [self.layer addSublayer:layer];
    
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
    
    [self.player play];
    [self.player seekToTime:self.range.start];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
    
    timerPlaying = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(playProgress) userInfo:nil repeats:YES];
    
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
        [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateStarted];
}

-(void)pause
{
    self.isPlaying = NO;
    
    [self.player pause];
    
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

@end
