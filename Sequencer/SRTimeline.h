//
//  SRTimeline.h
//  Sequencer
//
//  Created by Jon Como on 11/16/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DraggableCollectionViewFlowLayout.h"
#import "UICollectionView+Draggable.h"

@class SRSequencer;

@interface SRTimeline : UICollectionView <UICollectionViewDataSource_Draggable, UICollectionViewDelegateFlowLayout>

@property (nonatomic, weak) SRSequencer *sequence;

@end
