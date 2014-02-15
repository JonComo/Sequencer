//
//  SQClipsAnimationView.m
//  Sequencer
//
//  Created by Jon Como on 9/30/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipsAnimationView.h"

#import "SQClipsAnimationCell.h"

#define cellSize CGSizeMake(100,100)

@implementation SQClipsAnimationView
{
    NSMutableArray *cells;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        
    }
    return self;
}

-(void)createCells
{
    cells = [NSMutableArray array];
    
    int numberToMake = self.bounds.size.width / cellSize.width + 1;
    
    for (int i = 0; i<numberToMake; i++) {
        //SQClipsAnimationCell *cell = [[SQClipsAnimationCell alloc] init];
        
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
