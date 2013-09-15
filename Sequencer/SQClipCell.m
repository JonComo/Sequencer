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

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        //init
        [self setup];
    }
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setup];
    }
    
    return self;
}

-(void)setup
{
    
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"bye clip cell");
}

-(void)setClip:(SRClip *)clip
{
    _clip = clip;
    
    imageViewThumb.image = _clip.thumbnail;
    
    if (clip.isSelected)
    {
        imageViewThumb.layer.borderColor = [UIColor whiteColor].CGColor;
        imageViewThumb.layer.borderWidth = 2;
    }else{
        imageViewThumb.layer.borderWidth = 0;
    }
}

@end