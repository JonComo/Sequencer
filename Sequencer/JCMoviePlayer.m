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
}

@end

@implementation JCMoviePlayer

-(id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        //init
        
    }
    
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        //init
        
    }
    
    return self;
}

-(void)setURL:(NSURL *)URL
{
    _URL = URL;
    
    //refresh items
    playerItem = nil;
    [layer removeFromSuperlayer];
    layer = nil;
    self.player = nil;
    
    
    playerItem = [AVPlayerItem playerItemWithURL:URL];
    
    self.player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    
    layer = [AVPlayerLayer layer];
    layer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    [self.layer addSublayer:layer];
    
    layer.player = self.player;
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
    [self.player play];
}

-(void)pause
{
    [self.player pause];
}

-(void)stop
{
    [self.player pause];
    [self.player seekToTime:kCMTimeZero];
}

@end
