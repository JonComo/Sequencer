//
//  SQTimeline.h
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

#import "DraggableCollectionViewFlowLayout.h"
#import "UICollectionView+Draggable.h"

@class SRSequencer;
@class SRClip;

@interface SQTimeline : UICollectionView <UICollectionViewDataSource_Draggable, UICollectionViewDelegateFlowLayout>

@property (nonatomic, weak) SRSequencer *sequence;

@property CMTime currentTime;

-(void)deselectAll;
-(SRClip *)lastSelectedClip;
-(NSArray *)selectedClips;

-(void)scrollToTime:(CMTime)time animated:(BOOL)animated;
-(void)scrollToClip:(SRClip *)clip;
-(SRClip *)clipAtTime:(CMTime)time;

-(void)frameUpdated;

@end