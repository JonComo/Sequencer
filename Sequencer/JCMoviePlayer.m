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
}

@end

@implementation JCMoviePlayer

-(void)dealloc
{
    NSLog(@"dealloc player");
}

-(void)reset
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
     
    //refresh items
    playerItem = nil;
    [layer removeFromSuperlayer];
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
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
        [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateStarted];
    
    [self.player seekToTime:self.range.start];
    [self.player play];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
    timerPlaying = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(playProgress) userInfo:nil repeats:YES];
}

-(void)pause
{
    [self.player pause];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
}

-(void)stop
{
    [self.player pause];
    [self.player seekToTime:kCMTimeZero];
    
    [timerPlaying invalidate];
    timerPlaying = nil;
}

-(void)playProgress
{
    CMTime endTime = CMTimeAdd(self.range.start, self.range.duration);
    
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
    [self stop];
    [self reset];
    
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playingAtTime:)])
        [self.delegate moviePlayer:self playingAtTime:kCMTimeIndefinite];
    
    if ([self.delegate respondsToSelector:@selector(moviePlayer:playbackStateChanged:)])
        [self.delegate moviePlayer:self playbackStateChanged:JCMoviePlayerStateFinished];
}

@end
