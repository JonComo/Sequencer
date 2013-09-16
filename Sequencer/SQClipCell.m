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

-(void)setClip:(SRClip *)clip
{
    _clip = clip;
    
    [self layoutThumbs];
    
    if (clip.isSelected)
    {
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2;
    }else{
        self.layer.borderWidth = 0;
    }
}

-(void)layoutThumbs
{
    for (UIView *subview in self.subviews)
    {
        if ([subview isKindOfClass:[UIImageView class]])
            [subview removeFromSuperview];
    }
    
    float x = 0;
    
    CGSize size = [self.clip timelineSize];
    CGSize thumbnailSize = CGSizeMake(size.height, size.height);
    
    for (UIImage *thumb in self.clip.thumbnails)
    {
        UIImageView *thumbImageView = [[UIImageView alloc] initWithImage:thumb];
        thumbImageView.frame = CGRectMake(x, 0, thumbnailSize.width, thumbnailSize.height);
        thumbImageView.contentMode = UIViewContentModeScaleAspectFit;
        
        x += thumbnailSize.width;
        
        [self addSubview:thumbImageView];
    }
}

@end