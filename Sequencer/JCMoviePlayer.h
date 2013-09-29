//
//  JCMoviePlayer.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

typedef enum
{
    JCMoviePlayerStateStarted,
    JCMoviePlayerStateFinished
} JCMoviePlayerState;

@class JCMoviePlayer;

@protocol JCMoviePlayerDelegate <NSObject>

@optional
-(void)moviePlayer:(JCMoviePlayer *)player playingAtTime:(CMTime)currentTime;
-(void)moviePlayer:(JCMoviePlayer *)player playbackStateChanged:(JCMoviePlayerState)state;

@end

@interface JCMoviePlayer : UIView

@property (nonatomic, weak) id <JCMoviePlayerDelegate> delegate;

@property BOOL isPlaying;

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, assign) CMTimeRange range;

-(void)setupWithPlayerItem:(AVPlayerItem *)item;

-(void)play;
-(void)pause;
-(void)stop;

@end
