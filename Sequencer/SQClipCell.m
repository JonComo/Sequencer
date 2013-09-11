//
//  SQClipCell.m
//  Sequencer
//
//  Created by Jon Como on 8/31/13.
//  Copyright (c) 2013 Jon Como. All rights reserved.
//

#import "SQClipCell.h"

#import <QuartzCore/QuartzCore.h>

#import "SRClip.h"

@implementation SQClipCell
{
    __weak IBOutlet UIImageView *imageViewThumb;
}

-(void)setClip:(SRClip *)clip
{
    _clip = clip;
    
    imageViewThumb.image = _clip.thumbnail;
    
    if (clip.isSelected)
    {
        self.layer.borderColor = [UIColor redColor].CGColor;
        self.layer.borderWidth = 2;
    }else{
        self.layer.borderWidth = 0;
    }
}

@end