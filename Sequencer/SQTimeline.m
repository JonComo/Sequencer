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
    
    UIView *playhead;
    
    BOOL isSeeking;
}

-(void)reloadData
{
    [super reloadData];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SRSequenceRefreshPreview object:nil];
}

-(void)removeFromSuperview
{
    [playhead removeFromSuperview];
    
    [super removeFromSuperview];
}

-(void)setupContentInsets
{
    playhead = nil;
    
    float center = self.bounds.size.width/2;
    
    playhead = [[UIView alloc] initWithFrame:CGRectMake(self.frame.origin.x + center - 1, self.frame.origin.y + self.bounds.size.height * 3/4, 2, self.bounds.size.height * 1/4)];
    
    [playhead setUserInteractionEnabled:NO];
    [self.superview addSubview:playhead];
    
    playhead.backgroundColor = [UIColor whiteColor];
}

-(void)setSequence:(SRSequencer *)sequence
{
    _sequence = sequence;
    
    self.dataSource = _sequence;
    self.delegate = self;
    
    _currentTime = kCMTimeZero;
    
    if (!hasSetupLayout)
        [self setupLayout];
}

-(void)setupLayout
{
    hasSetupLayout = YES;
    
    self.decelerationRate = UIScrollViewDecelerationRateFast;
    
    LXReorderableCollectionViewFlowLayout *layout = [[LXReorderableCollectionViewFlowLayout alloc] init];
    [layout setMinimumInteritemSpacing:10];
    [layout setMinimumLineSpacing:10];
    
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    [self setCollectionViewLayout:layout];
    [self registerNib:[UINib nibWithNibName:@"clipCell" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"clipCell"];
}

-(void)playAtTime:(CMTime)time
{
//    float currentTime = CMTimeGetSeconds(time);
//    
//    float ratio = currentTime / CMTimeGetSeconds(self.sequence.duration);
//    
//    float playPosition = self.contentSize.width * ratio;
//    
//    [self scrollRectToVisible:CGRectMake(playPosition, 0, 2, self.bounds.size.height) animated:NO];
    
    self.currentTime = time;
    
    for (SRClip *clip in self.sequence.clips){
        BOOL isPlaying = [clip isPlayingAtTime:time];
        
        if (isPlaying){
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[self.sequence.clips indexOfObject:clip] inSection:0];
            SQClipCell *cell = (SQClipCell *)[self cellForItemAtIndexPath:indexPath];
            
            //calculate percent of cell played
            CMTimeRange difference = CMTimeRangeFromTimeToTime(clip.positionInComposition.start, time);
            
            float ratio = CMTimeGetSeconds(difference.duration) / CMTimeGetSeconds(clip.positionInComposition.duration);
            
            [self scrollRectToVisible:CGRectMake(cell.frame.origin.x + cell.bounds.size.width * ratio, 0, 2, 2) animated:NO];
        }
    }
}

-(void)scrollToClip:(SRClip *)clip
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger index = [self.sequence.clips indexOfObject:clip];
        
        NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
        SQClipCell *addedCell = (SQClipCell *)[self cellForItemAtIndexPath:path];
        
        [self scrollRectToVisible:CGRectMake(addedCell.frame.origin.x + addedCell.bounds.size.width, 0, 2, 2) animated:YES];
    });
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
}

//flow layout

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SRClip *clip = [self.sequence.clips objectAtIndex:indexPath.row];
    
    clip.isSelected = !clip.isSelected;
    
    [super reloadData];
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
    float center = self.bounds.size.width/2;
    float playheadPosition = center + scrollView.contentOffset.x;
    
    NSArray *cells = [self visibleCells];
    
    SQClipCell *closestCell;
    float dist = FLT_MAX;
    
    for (SQClipCell *cell in cells)
    {
        float cellX = cell.frame.origin.x + cell.frame.size.width/2;
        
        float testDist = ABS(cellX - playheadPosition);
        
        if (testDist < dist)
        {
            closestCell = cell;
            dist = testDist;
        }
    }
    
    //find ratio of scrolled past cell
    float ratio = (playheadPosition - closestCell.frame.origin.x) / closestCell.bounds.size.width;
    
    if (ratio < 0) ratio = 0;
    if (ratio > 1) ratio = 1;
    
    CMTime additionalTime = CMTimeMultiplyByFloat64(closestCell.clip.positionInComposition.duration, ratio);
    
    CMTime seekTime = CMTimeAdd(closestCell.clip.positionInComposition.start, additionalTime);
    
    self.currentTime = seekTime;
    
    if (isSeeking)
        [self.sequence.player seekToTime:seekTime];
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
