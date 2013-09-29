//
//  SQTimeline.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

@class SRSequencer;
@class SRClip;

@interface SQTimeline : UICollectionView

@property (nonatomic, weak) SRSequencer *sequence;

-(void)deselectAll;
-(SRClip *)lastSelectedClip;
-(NSArray *)selectedClips;

-(void)playAtTime:(CMTime)time;
-(void)finishedPlaying;

@end