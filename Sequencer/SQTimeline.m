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

//#import "LXReorderableCollectionViewFlowLayout.h"

@interface SQTimeline () <UIScrollViewDelegate>

@end

@implementation SQTimeline
{
    UIView *playhead;
    
    BOOL isSeeking;
}

-(void)reloadData
{
    [self.sequence refreshPreview];
    
    [super reloadData];
}

-(void)removeFromSuperview
{
    [playhead removeFromSuperview];
    
    [super removeFromSuperview];
}

-(void)frameUpdated
{
    [self setContentInset:UIEdgeInsetsMake(0, self.superview.frame.size.width/2, 0, self.superview.frame.size.width/2)];
    [self addPlayhead];
}

-(void)addPlayhead
{
    if (playhead) return;
    
    float center = self.bounds.size.width/2;
    
    playhead = [[UIView alloc] initWithFrame:CGRectMake(self.frame.origin.x + center - 1, self.frame.origin.y + self.bounds.size.height * 3/4, 2, self.bounds.size.height * 1/4)];
    
    [playhead setUserInteractionEnabled:NO];
    [self.superview addSubview:playhead];
    
    playhead.backgroundColor = [UIColor whiteColor];
}

-(void)setSequence:(SRSequencer *)sequence
{
    _sequence = sequence;
    
    [self setupLayout];
    
    self.dataSource = self;
    self.delegate = self;
    
    _currentTime = kCMTimeZero;
}

-(void)setupLayout
{
    self.draggable = YES;
    
    self.decelerationRate = UIScrollViewDecelerationRateFast;
    
    DraggableCollectionViewFlowLayout *layout = [[DraggableCollectionViewFlowLayout alloc] init];
    
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 0;
    
    [self setCollectionViewLayout:layout];
    [self registerNib:[UINib nibWithNibName:@"clipCell" bundle:[NSBundle mainBundle]] forCellWithReuseIdentifier:@"clipCell"];
}

-(SRClip *)clipAtTime:(CMTime)time
{
    for (SRClip *clip in self.sequence.clips){
        if ([clip isPlayingAtTime:time]){
            return clip;
        }
    }
    
    return nil;
}

-(void)scrollToTime:(CMTime)time animated:(BOOL)animated
{
    self.currentTime = time;
    
    float xOffset = 0;
    
    for (SRClip *clip in self.sequence.clips){
        if ([clip isPlayingAtTime:time]){
            
            //calculate percent of cell played
            CMTimeRange difference = CMTimeRangeFromTimeToTime(clip.positionInComposition.start, time);
            float ratio = CMTimeGetSeconds(difference.duration) / CMTimeGetSeconds(clip.positionInComposition.duration);
            [self scrollRectToVisible:CGRectMake(xOffset + clip.timelineSize.width * ratio, 0, 2, 2) animated:NO];
            
            break;
        }
        
        xOffset += clip.timelineSize.width;
    }
}

-(void)scrollToClip:(SRClip *)clip
{
    [self scrollToTime:CMTimeAdd(clip.positionInComposition.start, clip.positionInComposition.duration) animated:YES];
}

-(SRClip *)lastSelectedClip
{
    SRClip *selectedClip;
    
    for (SQClipCell *cell in [self visibleCells]){
        if (cell.clip.isSelected) selectedClip = cell.clip;
    }
    
    return selectedClip;
}

-(NSArray *)selectedClips
{
    NSMutableArray *clips = [NSMutableArray array];
    
    for (SQClipCell *cell in [self visibleCells]){
        if (cell.clip.isSelected)
            [clips addObject:cell.clip];
    }
    
    return clips;
}

-(void)deselectAll
{
    for (SRClip *clip in self.sequence.clips)
        clip.isSelected = NO;
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

-(BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

-(BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    return YES;
}

-(void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    id object1 = self.sequence.clips[fromIndexPath.row];
    id object2 = self.sequence.clips[toIndexPath.row];
    
    [self.sequence.clips replaceObjectAtIndex:toIndexPath.row withObject:object1];
    [self.sequence.clips replaceObjectAtIndex:fromIndexPath.row withObject:object2];
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SQClipCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"clipCell" forIndexPath:indexPath];
    
    SRClip *clip = [self.sequence.clips objectAtIndex:indexPath.row];
    
    cell.clip = clip;
    
    return cell;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.sequence.clips.count;
}

- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)fromIndexPath didMoveToIndexPath:(NSIndexPath *)toIndexPath
{
    SRClip *clip = [self.sequence.clips objectAtIndex:fromIndexPath.item];
    
    [self.sequence.clips removeObjectAtIndex:fromIndexPath.item];
    [self.sequence.clips insertObject:clip atIndex:toIndexPath.item];
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
    
    for (SQClipCell *cell in cells){
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
    
    if (!self.sequence.player.isPlaying)
        [self.sequence hidePreview];
}

@end
