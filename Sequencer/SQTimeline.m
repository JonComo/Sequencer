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

#import "JCMath.h"

#import "LXReorderableCollectionViewFlowLayout.h"

@interface SQTimeline () <UIScrollViewDelegate, UICollectionViewDelegateFlowLayout>

@end

@implementation SQTimeline
{
    BOOL hasSetupLayout;
    SRClip *clipCurrentlyPlaying;
    
    BOOL isSeeking;
    
    UIView *playhead;
}

-(void)setSequence:(SRSequencer *)sequence
{
    _sequence = sequence;
    
    self.dataSource = _sequence;
    self.delegate = self;
    
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

//flow layout

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [self.sequence.clips objectAtIndex:indexPath.row];
    
    clip.isSelected = !clip.isSelected;
    
    [self reloadData];
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [self.sequence.clips objectAtIndex:indexPath.row];
    
    return clip.timelineSize;
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    isSeeking = YES;
    
    [self.sequence showPreview];
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!isSeeking) return;
    
    float center = self.bounds.size.width/2;
    
    NSArray *cells = [self visibleCells];
    
    SQClipCell *closestCell;
    float dist = FLT_MAX;
    
    for (SQClipCell *cell in cells)
    {
        float cellX = cell.frame.origin.x + cell.frame.size.width - scrollView.contentOffset.x;
        
        NSLog(@"cellX: %f center:%f", cellX, center);
        
        float testDist = ABS(cellX - center);
        if (testDist < dist)
        {
            closestCell = cell;
            dist = testDist;
        }
    }
    
    [self.sequence.player seekToTime:closestCell.clip.positionInComposition.start];
    
    /*
    float scrollX = scrollView.contentOffset.x;
    
    float offsetX = scrollX + scrollView.contentInset.left;
    
    if (offsetX < 0) offsetX = 0;
    if (offsetX > scrollView.contentSize.width) offsetX = scrollView.contentSize.width;
    
    float difference = scrollView.contentSize.width - offsetX;
    
    float ratio = difference / scrollView.contentSize.width;
    
    ratio = [JCMath mapValue:ratio range:CGPointMake(0, 1) range:CGPointMake(0, 1)];
    
    NSLog(@"ratio = %f duration: %f", ratio, CMTimeGetSeconds(self.sequence.duration));
    
    [self.sequence.player seekToTime:CMTimeMultiplyByFloat64(self.sequence.duration, ratio)];
     */
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (isSeeking){
        isSeeking = NO;
        [self stopSeeking];
    }
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate && isSeeking)
    {
        isSeeking = NO;
        [self stopSeeking];
    }
}

-(void)stopSeeking
{
    isSeeking = NO;
    [self.sequence hidePreview];
}

@end
