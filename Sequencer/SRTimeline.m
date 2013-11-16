//
//  SRTimeline.m
//  Sequencer
//
//  Created by Jon Como on 11/16/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SRTimeline.h"

#import "SRSequencer.h"

#import "SQClipCell.h"

@implementation SRTimeline

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        
    }
    return self;
}

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

//Draggable

-(BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

-(BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    return YES;
}

@end
