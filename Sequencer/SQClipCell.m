//
//  SQClipCell.m
//  Sequencer
//
//  Created by Jon Como on 8/31/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipCell.h"

#import "SRClip.h"

@implementation SQClipCell
{
    __weak IBOutlet UIImageView *imageViewThumb;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void)setClip:(SRClip *)clip
{
    _clip = clip;
    
    imageViewThumb.image = _clip.thumbnail;
}

@end
