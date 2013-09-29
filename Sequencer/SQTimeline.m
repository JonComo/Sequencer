//
//  SQTimeline.m
//  Sequencer
//
//  Created by Jon Como on 9/14/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQTimeline.h"

#import "SQClipCell.h"

#import "SRClip.h"

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
    if (!playhead)
    {
        playhead = [[UIView alloc] initWithFrame:CGRectZero];
        [playhead setBackgroundColor:[UIColor clearColor]];
        playhead.layer.borderColor = [UIColor redColor].CGColor;
        playhead.layer.borderWidth = 2;
        [playhead setUserInteractionEnabled:NO];
    }
    
    for (SRClip *clip in self.sequence.clips){
        BOOL isPlaying = [clip isPlayingAtTime:time];
        
        if (isPlaying && clipCurrentlyPlaying != clip){
            clipCurrentlyPlaying = clip;
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self.sequence.clips indexOfObject:clip] inSection:0];
            [self scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:NO];
        }
        

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self.sequence.clips indexOfObject:clipCurrentlyPlaying] inSection:0];
        SQClipCell *cell = (SQClipCell *)[self cellForItemAtIndexPath:indexPath];
        
        if (!playhead.superview)
            [self addSubview:playhead];
        
        playhead.frame = cell.frame;
    }
}

-(void)finishedPlaying
{
    [playhead removeFromSuperview];
}

-(SRClip *)lastSelectedClip
{
    SRClip *selectedClip;
    
    for (SRClip *clip in self.sequence.clips){
        if (clip.isSelected) selectedClip = clip;
    }
    
    return selectedClip;
}

-(NSArray *)selectedClips
{
    NSMutableArray *clips = [NSMutableArray array];
    
    for (SRClip *clip in self.sequence.clips)
    {
        if (clip.isSelected)
            [clips addObject:clip];
    }
    
    return clips;
}

-(void)deselectAll
{
    for (SRClip *clip in self.sequence.clips){
        clip.isSelected = NO;
    }
    
    [self reloadData];
}

@end
