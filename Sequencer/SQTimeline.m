//
//  SQTimeline.m
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQTimeline.h"

#import "SQClipCell.h"

#import "SRSequencer.h"

#import "LXReorderableCollectionViewFlowLayout.h"

@implementation SQTimeline
{
    BOOL hasSetupLayout;
    SRClip *clipCurrentlyPlaying;
    
    UIView *playhead;
}

-(void)setSequence:(SRSequencer *)sequence
{
    _sequence = sequence;
    
    self.dataSource = _sequence;
    
    if (!hasSetupLayout)
        [self setupLayout];
}

-(void)reloadData
{
    [super reloadData];
    
    CGSize size = self.frame.size;
    self.contentInset = UIEdgeInsetsMake(0, size.width/3, 0, size.width/3);
}

-(void)setupLayout
{
    hasSetupLayout = YES;
    
    LXReorderableCollectionViewFlowLayout *layout = [[LXReorderableCollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:10];
    [layout setMinimumLineSpacing:10];
    
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    [self setCollectionViewLayout:layout];
    [self registerNib:[UINib nibWithNibName:@"clipCell" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"clipCell"];
}

-(void)playAtTime:(CMTime)time
{
    for (SRClip *clip in self.sequence.clips){
        BOOL isPlaying = [clip isPlayingAtTime:time];
        
        if (isPlaying && clipCurrentlyPlaying != clip){
            clipCurrentlyPlaying = clip;
            
            NSInteger index = [self.sequence.clips indexOfObject:clipCurrentlyPlaying];
            [self scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:YES];
        }
    }
}

@end
