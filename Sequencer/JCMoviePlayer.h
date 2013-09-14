//
//  JCMoviePlayer.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>

@interface JCMoviePlayer : UIView

@property (nonatomic, strong) NSURL *URL;

@property (nonatomic, strong) AVPlayer *player;

-(void)play;
-(void)pause;
-(void)stop;

@end
